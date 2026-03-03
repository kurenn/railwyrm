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
        "organization_name" => { "type" => "string", "required" => false, "default" => "Acme Recruiting" },
        "with_modules" => {
          "type" => "array",
          "required" => false,
          "default" => [],
          "allowed" => ["background_jobs"]
        }
      },
      "roles" => %w[admin recruiter],
      "gems" => {
        "required" => [{ "name" => "pundit" }],
        "optional_by_module" => {
          "background_jobs" => [{ "name" => "solid_queue" }]
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

  it "rejects invalid route definitions" do
    recipe = valid_recipe_hash.dup
    recipe["routes"] = {
      "authenticated" => [{ "type" => "root", "to" => "" }],
      "public" => [{ "type" => "bogus", "name" => "careers" }]
    }

    result = described_class.new.validate(recipe)

    expect(result).not_to be_valid
    expect(result.errors).to include("routes.authenticated[0].to must be a non-empty string for root routes")
    expect(result.errors).to include("routes.public[0].type must be one of: root, get, resources")
  end

  it "rejects invalid deploy and module setup sections" do
    recipe = valid_recipe_hash.dup
    recipe["module_setup"] = { "background_jobs" => { "commands" => "bin/rails x" } }
    recipe["deploy"] = { "presets" => { "render" => {} } }

    result = described_class.new.validate(recipe)

    expect(result).not_to be_valid
    expect(result.errors).to include("module_setup.background_jobs.commands must be an array")
    expect(result.errors).to include("deploy.presets.render must include copies and/or smoke_commands")
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

  it "accepts optional ui_profile when valid" do
    recipe = valid_recipe_hash.merge("ui_profile" => "dashboard_05")

    result = described_class.new.validate(recipe)

    expect(result).to be_valid
  end

  it "rejects blank optional ui_profile" do
    recipe = valid_recipe_hash.merge("ui_profile" => " ")

    result = described_class.new.validate(recipe)

    expect(result).not_to be_valid
    expect(result.errors).to include("ui_profile must be a non-empty string when present")
  end
end
