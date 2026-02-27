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
      expect(commands).to include("bin/rails generate claude_on_rails:swarm")
    end

    it "can skip devise user generation" do
      config = Railwyrm::Configuration.new(name: "demo_app", workspace: "/tmp", install_devise_user: false)
      commands = blueprint.post_bundle_steps(config).map { |(_label, command)| command.join(" ") }
      expect(commands).not_to include("bin/rails generate devise User")
    end
  end
end
