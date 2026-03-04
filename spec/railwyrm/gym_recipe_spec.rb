# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Gym reference recipe" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:recipe_path) { File.join(repo_root, "recipes/gym/recipe.yml") }

  def load_recipe_data
    YAML.safe_load(File.read(recipe_path), permitted_classes: [], aliases: false)
  end

  it "is schema-valid" do
    result = Railwyrm::RecipeSchema.new.validate_file(recipe_path)

    expect(result).to be_valid
  end

  it "is marked as reference" do
    data = load_recipe_data

    expect(data["status"]).to eq("reference")
  end

  it "has stable deterministic command boundaries" do
    recipe = Railwyrm::Recipe.load(recipe_path)
    commands = recipe.scaffolding_commands

    expect(commands.first).to eq("bin/rails generate pundit:install")
    expect(commands.last).to eq("bin/rails db:migrate")
  end

  it "references existing gym assets" do
    data = load_recipe_data
    referenced_paths = []

    referenced_paths << data.fetch("seed_data").fetch("file")
    if data["ui_profile"].to_s.strip != ""
      profile = data["ui_profile"]
      referenced_paths << "recipes/_shared/ui_profiles/#{profile}/views"
      referenced_paths << "recipes/_shared/ui_profiles/#{profile}/components"
    end
    data.fetch("ui_overlays").fetch("copies").each do |copy|
      referenced_paths << copy.fetch("from")
    end
    data.fetch("ai_assets").each_value do |paths|
      referenced_paths.concat(paths)
    end
    data.fetch("deploy").fetch("presets").each_value do |preset|
      next unless preset["copies"].is_a?(Array)

      preset["copies"].each { |copy| referenced_paths << copy.fetch("from") }
    end

    referenced_paths.each do |relative_path|
      full_path = File.join(repo_root, relative_path)
      expect(File.exist?(full_path)).to be(true), "Expected referenced path to exist: #{relative_path}"
    end
  end
end
