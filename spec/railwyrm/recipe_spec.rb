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
        "organization_name" => { "type" => "string", "required" => false },
        "with_modules" => {
          "type" => "array",
          "required" => false,
          "default" => [],
          "allowed" => ["background_jobs", "advanced_reports"]
        }
      },
      "roles" => %w[admin recruiter],
      "gems" => {
        "required" => [{ "name" => "pundit" }],
        "optional_by_module" => {
          "background_jobs" => [{ "name" => "solid_queue" }],
          "advanced_reports" => [{ "name" => "groupdate" }]
        }
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
      expect(recipe.routes.keys).to contain_exactly("authenticated", "public")
      expect(recipe.authorization_policies).to eq(["job_posting_policy"])
      expect(recipe.allowed_modules).to eq(["background_jobs", "advanced_reports"])
      expect(recipe.resolve_modules(["advanced_reports", "background_jobs"])).to eq(%w[background_jobs advanced_reports])
      expect(recipe.module_gems(["background_jobs"])).to eq(["solid_queue"])
      expect(recipe.module_setup_commands(["background_jobs"])).to eq(["bin/rails generate solid_queue:install"])
      expect(recipe.deploy_preset_names).to eq(["render"])
      expect(recipe.deploy_smoke_commands("render")).to eq(["bin/rails runner \"puts 'ok'\""])
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

  it "raises a helpful error for unknown modules and deploy presets" do
    recipe = described_class.new(
      path: "/tmp/demo-repo/recipes/ats/recipe.yml",
      data: valid_recipe_hash
    )

    expect { recipe.resolve_modules(["unknown_module"]) }
      .to raise_error(Railwyrm::InvalidConfiguration, /Unknown recipe module/)
    expect { recipe.deploy_preset("unknown_deploy") }
      .to raise_error(Railwyrm::InvalidConfiguration, /Unknown deploy preset/)
  end
end
