# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ATS reference recipe" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:recipe_path) { File.join(repo_root, "recipes/ats/recipe.yml") }

  def load_recipe_data
    YAML.safe_load(File.read(recipe_path), permitted_classes: [], aliases: false)
  end

  it "is schema-valid" do
    result = Railwyrm::RecipeSchema.new.validate_file(recipe_path)

    expect(result).to be_valid
  end

  it "is marked as a reference recipe" do
    data = load_recipe_data

    expect(data["status"]).to eq("reference")
  end

  it "has stable deterministic command boundaries" do
    recipe = Railwyrm::Recipe.load(recipe_path)
    commands = recipe.scaffolding_commands

    expect(commands.first).to eq("bin/rails generate pundit:install")
    expect(commands.last).to eq("bin/rails db:migrate")
    expect(commands).to include("bin/rails generate model Candidate company:references first_name:string last_name:string email:string:index phone:string location:string linkedin_url:string portfolio_url:string source:string notes:text")
  end

  it "references existing ats assets" do
    data = load_recipe_data
    referenced_paths = []

    referenced_paths << data.fetch("seed_data").fetch("file")
    data.fetch("ui_overlays").fetch("copies").each do |copy|
      referenced_paths << copy.fetch("from")
    end
    data.fetch("ai_assets").each_value do |paths|
      referenced_paths.concat(paths)
    end

    referenced_paths.each do |relative_path|
      full_path = File.join(repo_root, relative_path)
      expect(File.exist?(full_path)).to be(true), "Expected referenced path to exist: #{relative_path}"
    end
  end

  it "supports dry-run apply without mutating workspace" do
    recipe = Railwyrm::Recipe.load(recipe_path)

    Dir.mktmpdir do |workspace|
      ui = Railwyrm::UI::Buffer.new
      shell = Railwyrm::Shell.new(ui: ui, dry_run: true, verbose: false)
      executor = Railwyrm::RecipeExecutor.new(recipe, workspace: workspace, ui: ui, shell: shell, dry_run: true)

      expect { executor.apply! }.not_to raise_error
      expect(Dir.children(workspace)).to eq([])
    end
  end
end
