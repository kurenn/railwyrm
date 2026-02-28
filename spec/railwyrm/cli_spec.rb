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
        "organization_name" => { "type" => "string", "required" => false }
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

  it "exits with a non-zero status for invalid recipes" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, "id: ats\nname: bad")

      expect { described_class.start(["recipes", "validate", path]) }
        .to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end
  end
end
