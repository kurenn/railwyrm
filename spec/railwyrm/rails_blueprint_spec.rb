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
  end

  describe "#compatible_rails_requirement" do
    it "pins Rails 8.0 for Ruby 3.3" do
      expect(blueprint.compatible_rails_requirement("3.3.0")).to eq("~> 8.0.3")
    end

    it "does not pin Rails for Ruby 3.4 or newer" do
      expect(blueprint.compatible_rails_requirement("3.4.0")).to be_nil
    end
  end

  describe "#post_bundle_steps" do
    it "includes tailwind installer command" do
      commands = blueprint.post_bundle_steps(configuration).map { |(_label, command)| command.join(" ") }
      expect(commands).to include("./bin/rails tailwindcss:install")
    end

    it "includes untitled_ui installer command" do
      commands = blueprint.post_bundle_steps(configuration).map { |(_label, command)| command.join(" ") }
      expect(commands).to include("bin/rails generate untitled_ui:install")
    end

    it "includes claude-on-rails installer command" do
      commands = blueprint.post_bundle_steps(configuration).map { |(_label, command)| command.join(" ") }
      expect(commands).to include("bin/rails generate claude_on_rails:swarm --force")
    end

    it "can skip devise user generation" do
      config = Railwyrm::Configuration.new(name: "demo_app", workspace: "/tmp", install_devise_user: false)
      commands = blueprint.post_bundle_steps(config).map { |(_label, command)| command.join(" ") }
      expect(commands).not_to include("bin/rails generate devise User")
    end
  end

  describe "#gem_entries" do
    it "includes quality tooling and claude-on-rails github source in the default stack" do
      markers = blueprint.gem_entries.map { |entry| entry.fetch(:marker) }
      snippets = blueprint.gem_entries.map { |entry| entry.fetch(:snippet) }.join("\n")

      expect(markers).to include('gem "ruby-lsp"')
      expect(markers).to include('gem "brakeman"')
      expect(markers).to include('gem "rubocop-rails"')
      expect(markers).to include('gem "bullet"')
      expect(snippets).to include('gem "dotenv-rails"')
      expect(snippets).to include('gem "rubocop", require: false')
      expect(snippets).to include('gem "rubocop-rails", require: false')
      expect(snippets).to include('gem "claude-on-rails", github: "kurenn/claude-on-rails", branch: "main"')
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
