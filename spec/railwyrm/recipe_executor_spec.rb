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

  def recipe_with_commands(commands)
    Railwyrm::Recipe.new(
      path: "/tmp/recipe.yml",
      data: {
        "id" => "ats",
        "name" => "Applicant Tracking System",
        "version" => "0.1.0",
        "scaffolding_plan" => { "commands" => commands },
        "ui_overlays" => { "copies" => [] },
        "seed_data" => { "file" => __FILE__ }
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
      dry_run: true
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
            "seed_data" => { "file" => "recipes/ats/templates/seeds/ats.seeds.rb" }
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
end
