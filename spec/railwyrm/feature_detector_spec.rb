# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::FeatureDetector do
  it "detects installed features from model/routes/gemfile" do
    Dir.mktmpdir do |app_path|
      File.write(
        File.join(app_path, "Gemfile"),
        <<~RUBY
          source "https://rubygems.org"
          gem "devise-passwordless"
          gem "devise-webauthn"
          gem "brakeman", require: false
          gem "rubocop", require: false
          gem "rubocop-rails", require: false
          gem "bullet"
        RUBY
      )

      FileUtils.mkdir_p(File.join(app_path, "app/models"))
      File.write(
        File.join(app_path, "app/models/user.rb"),
        <<~RUBY
          class User < ApplicationRecord
            devise :trackable, :magic_link_authenticatable, :passkey_authenticatable, :confirmable
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

      FileUtils.mkdir_p(File.join(app_path, ".github/workflows"))
      File.write(File.join(app_path, ".github/workflows/ci.yml"), "name: CI\n")

      FileUtils.mkdir_p(File.join(app_path, "config/environments"))
      File.write(
        File.join(app_path, "config/environments/development.rb"),
        <<~RUBY
          Rails.application.configure do
            config.after_initialize do
              Bullet.enable = true
            end
          end
        RUBY
      )

      detector = described_class.new(app_path: app_path, devise_user_model: "User")
      expect(detector.detect).to eq(%w[confirmable trackable magic_link passkeys ci quality])
    end
  end
end
