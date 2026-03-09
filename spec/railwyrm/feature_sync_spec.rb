# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe Railwyrm::FeatureSync do
  it "rebuilds manifest from detected state" do
    Dir.mktmpdir do |app_path|
      File.write(
        File.join(app_path, "Gemfile"),
        <<~RUBY
          source "https://rubygems.org"
          gem "devise-passwordless"
        RUBY
      )

      FileUtils.mkdir_p(File.join(app_path, "app/models"))
      File.write(
        File.join(app_path, "app/models/user.rb"),
        <<~RUBY
          class User < ApplicationRecord
            devise :database_authenticatable, :registerable, :trackable, :magic_link_authenticatable
          end
        RUBY
      )

      FileUtils.mkdir_p(File.join(app_path, "config"))
      File.write(
        File.join(app_path, "config/routes.rb"),
        <<~RUBY
          Rails.application.routes.draw do
            namespace :passwordless do
              devise_for :users, controllers: { sessions: "devise/passwordless/sessions" }
            end
          end
        RUBY
      )

      state = Railwyrm::FeatureState.new(app_path: app_path, ui: Railwyrm::UI::Buffer.new)
      state.replace!(["confirmable"])

      ui = Railwyrm::UI::Buffer.new
      result = described_class.new(app_path: app_path, ui: ui).run!

      expect(result.fetch(:changed)).to be(true)
      expect(result.fetch(:added)).to eq(%w[magic_link trackable])
      expect(result.fetch(:removed)).to eq(["confirmable"])
      expect(result.fetch(:tracked_after)).to eq(%w[trackable magic_link])

      manifest = YAML.safe_load(
        File.read(File.join(app_path, ".railwyrm/features.yml")),
        permitted_classes: [],
        aliases: false
      )
      expect(manifest.fetch("features")).to eq(%w[trackable magic_link])
    end
  end

  it "supports dry run without writing manifest" do
    Dir.mktmpdir do |app_path|
      File.write(File.join(app_path, "Gemfile"), "source \"https://rubygems.org\"\n")
      FileUtils.mkdir_p(File.join(app_path, "app/models"))
      File.write(
        File.join(app_path, "app/models/user.rb"),
        <<~RUBY
          class User < ApplicationRecord
            devise :database_authenticatable, :registerable, :trackable
          end
        RUBY
      )

      ui = Railwyrm::UI::Buffer.new
      result = described_class.new(app_path: app_path, ui: ui, dry_run: true).run!

      expect(result.fetch(:changed)).to be(true)
      expect(result.fetch(:tracked_after)).to eq(["trackable"])
      expect(File).not_to exist(File.join(app_path, ".railwyrm/features.yml"))
    end
  end
end
