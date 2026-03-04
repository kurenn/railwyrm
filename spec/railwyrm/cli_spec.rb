# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::CLI do
  def valid_recipe_hash
    {
      "id" => "ats",
      "name" => "Applicant Tracking System",
      "version" => "0.1.0",
      "status" => "draft",
      "description" => "ATS baseline recipe",
      "base_stack" => {
        "source" => "railwyrm_default",
        "requires" => %w[devise rspec]
      },
      "inputs" => {
        "organization_name" => { "type" => "string", "required" => false },
        "with_modules" => {
          "type" => "array",
          "required" => false,
          "default" => [],
          "allowed" => ["background_jobs"]
        }
      },
      "roles" => %w[admin recruiter],
      "gems" => {
        "required" => [{ "name" => "pundit" }]
      },
      "data_model" => {
        "models" => {
          "job_posting" => { "fields" => ["title:string"] }
        }
      },
      "scaffolding_plan" => {
        "commands" => ["echo recipe_step"]
      },
      "ui_overlays" => {
        "copies" => [{ "from" => "recipes/ats/templates/views", "to" => "app/views" }]
      },
      "routes" => {
        "authenticated" => [{ "type" => "root", "to" => "ats/dashboard#show" }],
        "public" => [{ "type" => "resources", "name" => "careers" }]
      },
      "authorization" => {
        "policy_system" => "pundit",
        "baseline_policies" => ["job_posting_policy"]
      },
      "seed_data" => {
        "create_demo_data" => true,
        "fixtures" => ["1 company"],
        "file" => "recipes/ats/templates/seeds/ats.seeds.rb"
      },
      "quality_gates" => {
        "required_commands" => ["bundle exec rspec"],
        "acceptance_checks" => ["Auth works for recruiter role"]
      },
      "module_setup" => {
        "background_jobs" => {
          "commands" => ["bin/rails generate solid_queue:install"]
        }
      },
      "deploy" => {
        "presets" => {
          "render" => {
            "copies" => [{ "from" => "recipes/ats/templates/deploy/render", "to" => "." }],
            "smoke_commands" => ["bin/rails runner \"puts 'ok'\""]
          }
        }
      },
      "ai_assets" => {
        "agents" => ["recipes/ats/agents/expert.md"],
        "skills" => ["recipes/ats/skills/core/SKILL.md"],
        "prompts" => ["recipes/ats/prompt.md"],
        "playbooks" => ["recipes/ats/playbooks/feature-add.md"]
      }
    }
  end

  it "validates a recipe file successfully" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, YAML.dump(valid_recipe_hash))

      expect { described_class.start(["recipes", "validate", path]) }.not_to raise_error
    end
  end

  it "prints a deterministic recipe plan" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, YAML.dump(valid_recipe_hash))

      expect { described_class.start(["recipes", "plan", path, "--workspace", dir]) }.not_to raise_error
    end
  end

  it "lists available recipes" do
    expect { described_class.start(["recipes", "list"]) }
      .to output(/Available recipes.*ats@0\.1\.0/m).to_stdout
  end

  it "shows a recipe by name" do
    expect { described_class.start(["recipes", "show", "ats"]) }
      .to output(/Applicant Tracking System/).to_stdout
  end

  it "lists shared ui profiles" do
    expect { described_class.start(["recipes", "profiles"]) }
      .to output(/Shared UI profiles.*dashboard_05 \[ready\]/m).to_stdout
  end

  it "passes dry-run mode to shell when applying recipes" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, YAML.dump(valid_recipe_hash))
      shell = instance_double(Railwyrm::Shell, run!: true)
      executor = instance_double(Railwyrm::RecipeExecutor, apply!: true)
      allow(Railwyrm::Shell).to receive(:new).and_return(shell)
      allow(Railwyrm::RecipeExecutor).to receive(:new).and_return(executor)
      expect(Railwyrm::Shell).to receive(:new)
        .with(hash_including(dry_run: true, verbose: false))
        .and_return(shell)
      expect(Railwyrm::RecipeExecutor).to receive(:new)
        .with(instance_of(Railwyrm::Recipe), hash_including(shell: shell, dry_run: true))
        .and_return(executor)

      expect do
        described_class.start(["recipes", "apply", path, "--workspace", dir, "--dry-run"])
      end.not_to raise_error
    end
  end

  it "passes module and deploy options to recipe executor" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, YAML.dump(valid_recipe_hash))
      shell = instance_double(Railwyrm::Shell, run!: true)
      executor = instance_double(Railwyrm::RecipeExecutor, apply!: true)
      allow(Railwyrm::Shell).to receive(:new).and_return(shell)
      allow(Railwyrm::RecipeExecutor).to receive(:new).and_return(executor)

      described_class.start(
        [
          "recipes",
          "apply",
          path,
          "--workspace",
          dir,
          "--with",
          "background_jobs",
          "--deploy",
          "render"
        ]
      )

      expect(Railwyrm::RecipeExecutor).to have_received(:new)
        .with(
          instance_of(Railwyrm::Recipe),
          hash_including(selected_modules: ["background_jobs"], deploy_preset: "render")
        )
    end
  end

  it "exits with a non-zero status for invalid recipes" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, "id: ats\nname: bad")

      expect { described_class.start(["recipes", "validate", path]) }
        .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end
  end

  it "exits with a non-zero status for unknown ui_profile in validate" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      recipe = valid_recipe_hash.merge("ui_profile" => "does_not_exist")
      File.write(path, YAML.dump(recipe))

      expect { described_class.start(["recipes", "validate", path]) }
        .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end
  end

  it "exits with a non-zero status for unknown recipe in show" do
    expect { described_class.start(["recipes", "show", "does_not_exist"]) }
      .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
  end

  it "applies a named recipe during new flow" do
    Dir.mktmpdir do |workspace|
      app_name = "ats_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)
      recipe = instance_double(Railwyrm::Recipe, id: "ats", version: "0.1.0", path: "/tmp/ats.yml")
      step = Railwyrm::RecipeExecutor::Step.new(index: 1, command: "echo recipe_step")
      executor = instance_double(Railwyrm::RecipeExecutor, plan: [step], apply!: true)

      allow(Railwyrm::Generator).to receive(:new).and_return(generator)
      allow(Railwyrm::Recipe).to receive(:load).and_return(recipe)
      allow(Railwyrm::RecipeExecutor).to receive(:new).and_return(executor)

      expect do
        described_class.start(
          [
            "new",
            app_name,
            "--interactive=false",
            "--path",
            workspace,
            "--recipe",
            "ats",
            "--no-banner"
          ]
        )
      end.not_to raise_error

      expect(Railwyrm::Recipe).to have_received(:load)
        .with(File.expand_path("../../recipes/ats/recipe.yml", __dir__))
      expect(Railwyrm::RecipeExecutor).to have_received(:new)
        .with(recipe, hash_including(workspace: app_path, dry_run: false))
      expect(executor).to have_received(:apply!)
    end
  end

  it "applies an explicit recipe path during new flow" do
    Dir.mktmpdir do |workspace|
      app_name = "custom_recipe_app"
      app_path = File.join(workspace, app_name)
      recipe_path = File.join(workspace, "recipe.yml")
      File.write(recipe_path, YAML.dump(valid_recipe_hash))
      generator = instance_double(Railwyrm::Generator, run!: app_path)
      recipe = instance_double(Railwyrm::Recipe, id: "ats", version: "0.1.0", path: recipe_path)
      executor = instance_double(Railwyrm::RecipeExecutor, plan: [], apply!: true)

      allow(Railwyrm::Generator).to receive(:new).and_return(generator)
      allow(Railwyrm::Recipe).to receive(:load).and_return(recipe)
      allow(Railwyrm::RecipeExecutor).to receive(:new).and_return(executor)

      expect do
        described_class.start(
          [
            "new",
            app_name,
            "--interactive=false",
            "--path",
            workspace,
            "--recipe",
            recipe_path,
            "--no-banner"
          ]
        )
      end.not_to raise_error

      expect(Railwyrm::Recipe).to have_received(:load).with(File.expand_path(recipe_path))
      expect(executor).to have_received(:apply!)
    end
  end

  it "fails new flow for unknown recipe names before generation" do
    Dir.mktmpdir do |workspace|
      expect(Railwyrm::Generator).not_to receive(:new)

      expect do
        described_class.start(
          [
            "new",
            "unknown_recipe_app",
            "--interactive=false",
            "--path",
            workspace,
            "--recipe",
            "does_not_exist",
            "--no-banner"
          ]
        )
      end.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end
  end

  it "passes devise confirmable option in non-interactive new flow" do
    Dir.mktmpdir do |workspace|
      app_name = "confirmable_cli_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)

      expect(Railwyrm::Generator).to receive(:new) do |config, ui:|
        expect(config.devise_confirmable?).to be(true)
        expect(config.install_devise_user?).to be(true)
        expect(ui).to be_a(Railwyrm::UI::Console)
        generator
      end

      expect do
        described_class.start(
          [
            "new",
            app_name,
            "--interactive=false",
            "--path",
            workspace,
            "--devise_confirmable=true",
            "--no-banner"
          ]
        )
      end.not_to raise_error
    end
  end

  it "uses a label default for interactive sign-in layout selection" do
    Dir.mktmpdir do |workspace|
      app_name = "wizard_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)
      prompt = instance_double(TTY::Prompt)

      allow(Railwyrm::Generator).to receive(:new).and_return(generator)
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive(:ask) do |question, **_kwargs|
        if question.include?("App name")
          app_name
        elsif question.include?("Workspace path")
          workspace
        else
          "User"
        end
      end
      allow(prompt).to receive(:yes?).and_return(false)
      expect(prompt).to receive(:select)
        .with("🧩 Select sign-in layout:", default: "Card Combined (recommended)")
        .and_return("card_combined")

      expect { described_class.start(["new", app_name, "--path", workspace, "--no-banner"]) }.not_to raise_error
    end
  end

  it "asks for devise confirmable in interactive new flow" do
    Dir.mktmpdir do |workspace|
      app_name = "wizard_confirmable_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)
      prompt = instance_double(TTY::Prompt)

      expect(Railwyrm::Generator).to receive(:new) do |config, ui:|
        expect(config.devise_confirmable?).to be(true)
        expect(ui).to be_a(Railwyrm::UI::Console)
        generator
      end
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive(:ask) do |question, **_kwargs|
        if question.include?("App name")
          app_name
        elsif question.include?("Workspace path")
          workspace
        else
          "User"
        end
      end
      expect(prompt).to receive(:yes?).with("🔐 Generate Devise user model now?", default: true).and_return(true)
      expect(prompt).to receive(:yes?)
        .with("✉️ Enable Devise confirmable (email confirmation required)?", default: false)
        .and_return(true)
      expect(prompt).to receive(:select)
        .with("🧩 Select sign-in layout:", default: "Card Combined (recommended)")
        .and_return("card_combined")
      expect(prompt).to receive(:yes?).with("🧩 Apply a recipe after base app generation?", default: false).and_return(false)

      expect { described_class.start(["new", app_name, "--path", workspace, "--no-banner"]) }.not_to raise_error
    end
  end

  it "prompts for optional recipe selection in interactive new flow" do
    Dir.mktmpdir do |workspace|
      app_name = "wizard_recipe_app"
      app_path = File.join(workspace, app_name)
      recipe_path = File.expand_path("../../recipes/ats/recipe.yml", __dir__)
      generator = instance_double(Railwyrm::Generator, run!: app_path)
      recipe = instance_double(
        Railwyrm::Recipe,
        id: "ats",
        name: "Applicant Tracking System",
        version: "0.1.0",
        metadata: { "status" => "reference" },
        path: recipe_path
      )
      executor = instance_double(Railwyrm::RecipeExecutor, plan: [], apply!: true)
      prompt = instance_double(TTY::Prompt)

      allow(Railwyrm::Generator).to receive(:new).and_return(generator)
      allow(Railwyrm::Recipe).to receive(:load).and_return(recipe)
      allow(Railwyrm::RecipeExecutor).to receive(:new).and_return(executor)
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive(:ask) do |question, **_kwargs|
        if question.include?("App name")
          app_name
        elsif question.include?("Workspace path")
          workspace
        else
          "User"
        end
      end
      allow(prompt).to receive(:yes?) do |question, **_kwargs|
        question.include?("Apply a recipe")
      end
      expect(prompt).to receive(:select)
        .with("🧩 Select sign-in layout:", default: "Card Combined (recommended)")
        .and_return("card_combined")
      expect(prompt).to receive(:select)
        .with("📚 Select a recipe:")
        .and_return(recipe_path)

      expect { described_class.start(["new", app_name, "--path", workspace, "--no-banner"]) }.not_to raise_error
      expect(Railwyrm::RecipeExecutor).to have_received(:new)
        .with(recipe, hash_including(workspace: app_path, dry_run: false))
      expect(executor).to have_received(:apply!)
    end
  end
end
