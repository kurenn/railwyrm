# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::RecipeSchema do
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
        "organization_name" => { "type" => "string", "required" => false, "default" => "Acme Recruiting" }
      },
      "roles" => %w[admin recruiter],
      "gems" => {
        "required" => [{ "name" => "pundit" }],
        "optional_by_module" => {
          "background_jobs" => [{ "name" => "sidekiq" }]
        }
      },
      "data_model" => {
        "models" => {
          "job_posting" => { "fields" => ["title:string"] }
        }
      },
      "scaffolding_plan" => {
        "commands" => ["bin/rails generate pundit:install"]
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

  it "accepts a valid recipe document" do
    result = described_class.new.validate(valid_recipe_hash)

    expect(result).to be_valid
    expect(result.errors).to be_empty
  end

  it "rejects missing required keys" do
    recipe = valid_recipe_hash.dup
    recipe.delete("ai_assets")

    result = described_class.new.validate(recipe)

    expect(result).not_to be_valid
    expect(result.errors).to include("Missing required key: ai_assets")
    expect(result.errors).to include("ai_assets must be a mapping")
  end

  it "rejects unknown top-level keys" do
    recipe = valid_recipe_hash.merge("foo" => "bar")

    result = described_class.new.validate(recipe)

    expect(result).not_to be_valid
    expect(result.errors).to include("Unknown top-level key: foo")
  end

  it "rejects invalid nested types" do
    recipe = valid_recipe_hash.dup
    recipe["base_stack"] = { "source" => "railwyrm_default", "requires" => "devise" }
    recipe["routes"] = { "authenticated" => [], "public" => "invalid" }

    result = described_class.new.validate(recipe)

    expect(result).not_to be_valid
    expect(result.errors).to include("base_stack.requires must be an array")
    expect(result.errors).to include("routes.public must be an array")
  end

  it "returns a parse error for malformed yaml files" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "recipe.yml")
      File.write(path, "id: ats\nname: [bad")

      result = described_class.new.validate_file(path)

      expect(result).not_to be_valid
      expect(result.errors.first).to match(/YAML parse error:/)
    end
  end

  it "returns a friendly error when file does not exist" do
    path = File.join(Dir.tmpdir, "missing-recipe-#{Process.pid}.yml")
    result = described_class.new.validate_file(path)

    expect(result).not_to be_valid
    expect(result.errors).to eq(["Recipe file not found: #{path}"])
  end
end
