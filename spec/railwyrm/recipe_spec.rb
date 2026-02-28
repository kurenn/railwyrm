# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::Recipe do
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
        "commands" => [
          "echo one",
          "echo two"
        ]
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

  it "loads a valid recipe file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, YAML.dump(valid_recipe_hash))

      recipe = described_class.load(path)

      expect(recipe.id).to eq("ats")
      expect(recipe.version).to eq("0.1.0")
      expect(recipe.scaffolding_commands).to eq(["echo one", "echo two"])
      expect(recipe.path).to eq(File.expand_path(path))
      expect(recipe.ui_overlay_copies).to eq([{ "from" => "recipes/ats/templates/views", "to" => "app/views" }])
      expect(recipe.seed_data_file).to eq("recipes/ats/templates/seeds/ats.seeds.rb")
      expect(recipe.quality_gate_commands).to eq(["bundle exec rspec"])
      expect(recipe.metadata).to include(
        "id" => "ats",
        "name" => "Applicant Tracking System",
        "version" => "0.1.0",
        "status" => "draft"
      )
    end
  end

  it "raises on invalid recipe files" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, "id: ats\nname: bad")

      expect { described_class.load(path) }
        .to raise_error(Railwyrm::InvalidConfiguration, /Invalid recipe/)
    end
  end

  it "resolves repository-relative references from recipes path" do
    recipe = described_class.new(
      path: "/tmp/demo-repo/recipes/ats/recipe.yml",
      data: {}
    )

    resolved = recipe.resolve_reference_path("recipes/ats/templates/views")

    expect(resolved).to eq("/tmp/demo-repo/recipes/ats/templates/views")
  end
end
