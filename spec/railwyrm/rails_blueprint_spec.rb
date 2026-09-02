# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::RailsBlueprint do
  subject(:blueprint) { described_class.new }

  let(:configuration) do
    Railwyrm::Configuration.new(name: "demo_app", workspace: "/tmp")
  end

  describe "#rails_new_command" do
    it "enforces postgres, tailwind, and no minitest" do
      expect(blueprint.rails_new_command(configuration)).to eq(
        ["rails", "new", "demo_app", "--database=postgresql", "--css=tailwind", "--skip-test", "--skip-bundle"]
      )
    end

    it "generates with an explicit Rails version when one is given" do
      command = blueprint.rails_new_command(configuration, rails_version: "8.0.3")

      expect(command.first(4)).to eq(["rails", "_8.0.3_", "new", "demo_app"])
    end
  end

  describe "#default_rails_version" do
    it "names the Rails version Railwyrm generates with" do
      expect(blueprint.default_rails_version).to eq("8.1.3.1")
    end
  end

  describe "#post_bundle_steps" do
    it "includes tailwind installer command" do
      commands = blueprint.post_bundle_steps(configuration).map { |(_label, command)| command.join(" ") }
      expect(commands).to include("./bin/rails tailwindcss:install")
    end

    it "re-bundles after the installers that can edit the Gemfile" do
      commands = blueprint.post_bundle_steps(configuration).map { |(_label, command)| command.join(" ") }

      expect(commands.index("bundle install")).to be > commands.index("bin/rails active_storage:install")
      expect(commands.index("bundle install")).to be < commands.index("bin/rails generate rspec:install")
    end

    it "can skip devise user generation" do
      config = Railwyrm::Configuration.new(name: "demo_app", workspace: "/tmp", install_devise_user: false)
      commands = blueprint.post_bundle_steps(config).map { |(_label, command)| command.join(" ") }
      expect(commands).not_to include("bin/rails generate devise User")
    end
  end

  describe "#gem_entries" do
    it "includes quality tooling in the default stack" do
      markers = blueprint.gem_entries.map { |entry| entry.fetch(:marker) }
      snippets = blueprint.gem_entries.map { |entry| entry.fetch(:snippet) }.join("\n")

      expect(markers).to include('gem "ruby-lsp"')
      expect(markers).to include('gem "brakeman"')
      expect(markers).to include('gem "rubocop-rails"')
      expect(markers).to include('gem "bullet"')
      expect(snippets).to include('gem "dotenv-rails"')
      expect(snippets).to include('gem "rubocop", require: false')
      expect(snippets).to include('gem "rubocop-rails", require: false')
    end
  end

  describe "#optional_gem_entries" do
    it "includes devise-passwordless when magic-link sign-in is requested" do
      config = Railwyrm::Configuration.new(name: "demo_app", workspace: "/tmp", devise_magic_link: true)
      markers = blueprint.optional_gem_entries(config).map { |entry| entry.fetch(:marker) }

      expect(markers).to include('gem "devise-passwordless"')
    end

    it "returns no optional gems when magic-link sign-in is disabled" do
      markers = blueprint.optional_gem_entries(configuration).map { |entry| entry.fetch(:marker) }

      expect(markers).to be_empty
    end

    it "includes devise-webauthn when passkeys sign-in is requested" do
      config = Railwyrm::Configuration.new(name: "demo_app", workspace: "/tmp", devise_passkeys: true)
      markers = blueprint.optional_gem_entries(config).map { |entry| entry.fetch(:marker) }

      expect(markers).to include('gem "devise-webauthn"')
    end
  end
end
