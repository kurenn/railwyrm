# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::RecipeExecutor do
  class RecipeExecutorFakeShell
    attr_reader :commands

    def initialize
      @commands = []
    end

    def run!(*command, chdir: nil)
      commands << { command: command, chdir: chdir }
      true
    end
  end

  def recipe_with_commands(commands, quality_gates: [])
    Railwyrm::Recipe.new(
      path: "/tmp/recipe.yml",
      data: {
        "id" => "ats",
        "name" => "Applicant Tracking System",
        "version" => "0.1.0",
        "scaffolding_plan" => { "commands" => commands },
        "ui_overlays" => { "copies" => [] },
        "seed_data" => { "file" => __FILE__ },
        "quality_gates" => { "required_commands" => quality_gates },
        "routes" => {},
        "authorization" => { "baseline_policies" => [] }
      }
    )
  end

  def recipe_with_modules_and_deploy(commands:, quality_gates:, module_setup:, deploy:, required_gems: [])
    Railwyrm::Recipe.new(
      path: "/tmp/recipe.yml",
      data: {
        "id" => "ats",
        "name" => "Applicant Tracking System",
        "version" => "0.1.0",
        "inputs" => {
          "with_modules" => {
            "type" => "array",
            "required" => false,
            "default" => [],
            "allowed" => ["background_jobs"]
          }
        },
        "gems" => {
          "required" => required_gems.map { |name| { "name" => name } },
          "optional_by_module" => {
            "background_jobs" => [{ "name" => "solid_queue" }]
          }
        },
        "module_setup" => {
          "background_jobs" => {
            "commands" => module_setup
          }
        },
        "scaffolding_plan" => { "commands" => commands },
        "ui_overlays" => { "copies" => [] },
        "seed_data" => { "file" => __FILE__ },
        "quality_gates" => { "required_commands" => quality_gates },
        "routes" => {},
        "authorization" => { "baseline_policies" => [] },
        "deploy" => deploy
      }
    )
  end

  it "produces a deterministic plan in recipe order" do
    recipe = recipe_with_commands(["echo first", "echo second"])
    executor = described_class.new(
      recipe,
      workspace: "/tmp",
      ui: Railwyrm::UI::Buffer.new,
      shell: RecipeExecutorFakeShell.new,
      dry_run: true
    )

    plan = executor.plan

    expect(plan.map(&:index)).to eq([1, 2])
    expect(plan.map(&:command)).to eq(["echo first", "echo second"])
  end

  it "applies commands in the same order as the plan" do
    Dir.mktmpdir do |workspace|
      shell = RecipeExecutorFakeShell.new
      recipe = recipe_with_commands(["echo one", "echo two"])
      executor = described_class.new(
        recipe,
        workspace: workspace,
        ui: Railwyrm::UI::Buffer.new,
        shell: shell,
        dry_run: true
      )

      executor.apply!

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to eq(["echo one", "echo two"])
      expect(shell.commands.map { |entry| entry[:chdir] }).to all(eq(File.expand_path(workspace)))
    end
  end

  it "fails when workspace does not exist" do
    missing_workspace = File.join(Dir.tmpdir, "missing-workspace-#{Process.pid}")
    recipe = recipe_with_commands(["echo one"])
    executor = described_class.new(
      recipe,
      workspace: missing_workspace,
      ui: Railwyrm::UI::Buffer.new,
      shell: RecipeExecutorFakeShell.new,
      dry_run: false
    )

    expect { executor.apply! }
      .to raise_error(Railwyrm::InvalidConfiguration, /Workspace does not exist/)
  end

  it "respects dry run mode via shell and avoids command side effects" do
    Dir.mktmpdir do |workspace|
      marker = File.join(workspace, "dry-run-marker.txt")
      recipe = recipe_with_commands(["touch #{marker}"])
      ui = Railwyrm::UI::Buffer.new
      shell = Railwyrm::Shell.new(ui: ui, dry_run: true, verbose: false)
      executor = described_class.new(recipe, workspace: workspace, ui: ui, shell: shell, dry_run: true)

      executor.apply!

      expect(File).not_to exist(marker)
    end
  end

  it "allows dry-run apply when workspace does not exist" do
    missing_workspace = File.join(Dir.tmpdir, "missing-workspace-dry-run-#{Process.pid}")
    recipe = recipe_with_commands(["echo one"])
    ui = Railwyrm::UI::Buffer.new
    shell = Railwyrm::Shell.new(ui: ui, dry_run: true, verbose: false)
    executor = described_class.new(
      recipe,
      workspace: missing_workspace,
      ui: ui,
      shell: shell,
      dry_run: true
    )

    expect { executor.apply! }.not_to raise_error
  end

  it "copies overlay assets and installs seed loader during apply" do
    Dir.mktmpdir do |repo_root|
      Dir.mktmpdir do |workspace|
        recipe_dir = File.join(repo_root, "recipes/ats")
        views_source = File.join(recipe_dir, "templates/views")
        seeds_source = File.join(recipe_dir, "templates/seeds")
        FileUtils.mkdir_p(views_source)
        FileUtils.mkdir_p(seeds_source)
        File.write(File.join(views_source, "dashboard.html.erb"), "<h1>ATS</h1>\n")
        File.write(File.join(seeds_source, "ats.seeds.rb"), "puts :seeded\n")

        FileUtils.mkdir_p(File.join(workspace, "db"))
        File.write(File.join(workspace, "db/seeds.rb"), "# base seeds\n")
        FileUtils.mkdir_p(File.join(workspace, "config"))
        File.write(File.join(workspace, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")

        recipe = Railwyrm::Recipe.new(
          path: File.join(recipe_dir, "recipe.yml"),
          data: {
            "id" => "ats",
            "name" => "Applicant Tracking System",
            "version" => "0.1.0",
            "scaffolding_plan" => { "commands" => [] },
            "ui_overlays" => {
              "copies" => [
                { "from" => "recipes/ats/templates/views", "to" => "app/views" }
              ]
            },
            "seed_data" => { "file" => "recipes/ats/templates/seeds/ats.seeds.rb" },
            "quality_gates" => { "required_commands" => [] }
          }
        )

        executor = described_class.new(
          recipe,
          workspace: workspace,
          ui: Railwyrm::UI::Buffer.new,
          shell: RecipeExecutorFakeShell.new,
          dry_run: false
        )

        executor.apply!

        copied_view = File.join(workspace, "app/views/dashboard.html.erb")
        copied_seed = File.join(workspace, "db/seeds/ats.seeds.rb")
        seeds_rb = File.read(File.join(workspace, "db/seeds.rb"))

        expect(File).to exist(copied_view)
        expect(File).to exist(copied_seed)
        expect(seeds_rb).to include("load Rails.root.join(\"db/seeds/ats.seeds.rb\")")
      end
    end
  end

  it "runs quality gate commands after scaffold commands" do
    Dir.mktmpdir do |workspace|
      FileUtils.mkdir_p(File.join(workspace, "config"))
      File.write(File.join(workspace, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
      shell = RecipeExecutorFakeShell.new
      recipe = recipe_with_commands(["echo build"], quality_gates: ["echo gate_one", "echo gate_two"])
      executor = described_class.new(
        recipe,
        workspace: workspace,
        ui: Railwyrm::UI::Buffer.new,
        shell: shell,
        dry_run: false
      )

      executor.apply!

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to eq(["echo build", "echo gate_one", "echo gate_two"])
    end
  end

  it "adds selected module gems and runs module setup commands" do
    Dir.mktmpdir do |workspace|
      File.write(File.join(workspace, "Gemfile"), "source 'https://rubygems.org'\n")
      FileUtils.mkdir_p(File.join(workspace, "config"))
      File.write(File.join(workspace, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
      shell = RecipeExecutorFakeShell.new
      recipe = recipe_with_modules_and_deploy(
        commands: ["echo build"],
        quality_gates: [],
        module_setup: ["echo setup_background_jobs"],
        deploy: {},
        required_gems: ["pundit"]
      )
      executor = described_class.new(
        recipe,
        workspace: workspace,
        ui: Railwyrm::UI::Buffer.new,
        shell: shell,
        dry_run: false,
        selected_modules: ["background_jobs"]
      )

      executor.apply!

      gemfile = File.read(File.join(workspace, "Gemfile"))
      expect(gemfile).to include('gem "pundit"')
      expect(gemfile).to include('gem "solid_queue"')

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to eq(["bundle install", "echo build", "echo setup_background_jobs"])
    end
  end

  it "applies deploy preset copies and runs deploy smoke commands" do
    Dir.mktmpdir do |workspace|
      source_file = File.join(workspace, "render-template.yaml")
      File.write(source_file, "service: ats\n")
      FileUtils.mkdir_p(File.join(workspace, "config"))
      File.write(File.join(workspace, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
      shell = RecipeExecutorFakeShell.new
      recipe = recipe_with_modules_and_deploy(
        commands: ["echo build"],
        quality_gates: ["echo gate"],
        module_setup: [],
        deploy: {
          "presets" => {
            "render" => {
              "copies" => [{ "from" => source_file, "to" => "render.yaml" }],
              "smoke_commands" => ["echo deploy_smoke"]
            }
          }
        }
      )
      executor = described_class.new(
        recipe,
        workspace: workspace,
        ui: Railwyrm::UI::Buffer.new,
        shell: shell,
        dry_run: false,
        deploy_preset: "render"
      )

      executor.apply!

      expect(File.read(File.join(workspace, "render.yaml"))).to include("service: ats")
      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to eq(["echo build", "echo gate", "echo deploy_smoke"])
    end
  end

  it "includes module setup and deploy smoke commands in the plan order" do
    recipe = recipe_with_modules_and_deploy(
      commands: ["echo build"],
      quality_gates: ["echo gate"],
      module_setup: ["echo setup_background_jobs"],
      deploy: {
        "presets" => {
          "render" => {
            "smoke_commands" => ["echo deploy_smoke"]
          }
        }
      }
    )
    executor = described_class.new(
      recipe,
      workspace: "/tmp",
      ui: Railwyrm::UI::Buffer.new,
      shell: RecipeExecutorFakeShell.new,
      dry_run: true,
      selected_modules: ["background_jobs"],
      deploy_preset: "render"
    )

    expect(executor.plan.map(&:command)).to eq(
      ["bundle install", "echo build", "echo setup_background_jobs", "echo gate", "echo deploy_smoke"]
    )
  end

  it "writes recipe routes and creates controller/policy stubs" do
    Dir.mktmpdir do |workspace|
      FileUtils.mkdir_p(File.join(workspace, "config"))
      File.write(
        File.join(workspace, "config/routes.rb"),
        <<~RUBY
          Rails.application.routes.draw do
          end
        RUBY
      )

      recipe = Railwyrm::Recipe.new(
        path: "/tmp/recipe.yml",
        data: {
          "id" => "ats",
          "name" => "Applicant Tracking System",
          "version" => "0.1.0",
          "scaffolding_plan" => { "commands" => [] },
          "ui_overlays" => { "copies" => [] },
          "seed_data" => { "file" => __FILE__ },
          "quality_gates" => { "required_commands" => [] },
          "routes" => {
            "authenticated" => [
              { "type" => "root", "to" => "ats/dashboard#show", "as" => "authenticated_root" },
              { "type" => "resources", "name" => "job_postings", "only" => %w[index show] },
              { "type" => "get", "path" => "reports", "to" => "ats/reports#index" }
            ],
            "public" => [
              { "type" => "resources", "name" => "careers", "only" => %w[index show], "controller" => "public/careers" }
            ]
          },
          "authorization" => { "baseline_policies" => %w[job_posting_policy report_policy] }
        }
      )

      executor = described_class.new(
        recipe,
        workspace: workspace,
        ui: Railwyrm::UI::Buffer.new,
        shell: RecipeExecutorFakeShell.new,
        dry_run: false
      )

      executor.apply!

      routes_content = File.read(File.join(workspace, "config/routes.rb"))
      expect(routes_content).to include("# BEGIN railwyrm:recipe:ats")
      expect(routes_content).to include("unauthenticated :user do")
      expect(routes_content).to include("root to: redirect(\"/users/sign_in\")")
      expect(routes_content).to include("authenticated :user do")
      expect(routes_content).to include("root to: \"ats/dashboard#show\", as: :authenticated_root")
      expect(routes_content).to include("resources :careers, only: [:index, :show], controller: \"public/careers\"")

      expect(File).to exist(File.join(workspace, "app/controllers/ats/dashboard_controller.rb"))
      expect(File).to exist(File.join(workspace, "app/controllers/ats/reports_controller.rb"))
      expect(File).to exist(File.join(workspace, "app/controllers/job_postings_controller.rb"))
      expect(File).to exist(File.join(workspace, "app/controllers/public/careers_controller.rb"))

      policy_content = File.read(File.join(workspace, "app/policies/job_posting_policy.rb"))
      expect(policy_content).to include("class JobPostingPolicy < ApplicationPolicy")
      expect(File).to exist(File.join(workspace, "app/policies/report_policy.rb"))
    end
  end

  it "does not inject devise sign-in root when recipe defines a public root" do
    Dir.mktmpdir do |workspace|
      FileUtils.mkdir_p(File.join(workspace, "config"))
      File.write(
        File.join(workspace, "config/routes.rb"),
        <<~RUBY
          Rails.application.routes.draw do
          end
        RUBY
      )

      recipe = Railwyrm::Recipe.new(
        path: "/tmp/recipe.yml",
        data: {
          "id" => "site",
          "name" => "Public Site",
          "version" => "0.1.0",
          "scaffolding_plan" => { "commands" => [] },
          "ui_overlays" => { "copies" => [] },
          "seed_data" => { "file" => __FILE__ },
          "quality_gates" => { "required_commands" => [] },
          "routes" => {
            "authenticated" => [],
            "public" => [
              { "type" => "root", "to" => "public/home#show" }
            ]
          },
          "authorization" => { "baseline_policies" => [] }
        }
      )

      executor = described_class.new(
        recipe,
        workspace: workspace,
        ui: Railwyrm::UI::Buffer.new,
        shell: RecipeExecutorFakeShell.new,
        dry_run: false
      )

      executor.apply!

      routes_content = File.read(File.join(workspace, "config/routes.rb"))
      expect(routes_content).to include("root to: \"public/home#show\"")
      expect(routes_content).not_to include("root to: redirect(\"/users/sign_in\")")
    end
  end
end
