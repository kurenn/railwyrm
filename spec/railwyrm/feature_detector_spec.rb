# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::FeatureDetector do
  def write_devise_migration!(app_path, columns)
    FileUtils.mkdir_p(File.join(app_path, "db/migrate"))
    File.write(
      File.join(app_path, "db/migrate/20260101000000_devise_create_users.rb"),
      <<~RUBY
        class DeviseCreateUsers < ActiveRecord::Migration[8.0]
          def change
            create_table :users do |t|
              #{columns.map { |column| "t.string :#{column}" }.join("\n      ")}
            end
          end
        end
      RUBY
    )
  end

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

      write_devise_migration!(app_path, %w[confirmation_token sign_in_count])

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

  it "does not treat a declared devise module as installed when its columns are missing" do
    Dir.mktmpdir do |app_path|
      File.write(File.join(app_path, "Gemfile"), "source \"https://rubygems.org\"\n")

      FileUtils.mkdir_p(File.join(app_path, "app/models"))
      File.write(
        File.join(app_path, "app/models/user.rb"),
        <<~RUBY
          class User < ApplicationRecord
            devise :database_authenticatable, :confirmable, :lockable, :trackable, :timeoutable
          end
        RUBY
      )

      write_devise_migration!(app_path, %w[email encrypted_password])

      detector = described_class.new(app_path: app_path, devise_user_model: "User")
      expect(detector.detect).to eq(["timeoutable"])
    end
  end

  it "accepts columns recorded in schema.rb" do
    Dir.mktmpdir do |app_path|
      File.write(File.join(app_path, "Gemfile"), "source \"https://rubygems.org\"\n")

      FileUtils.mkdir_p(File.join(app_path, "app/models"))
      File.write(
        File.join(app_path, "app/models/user.rb"),
        <<~RUBY
          class User < ApplicationRecord
            devise :database_authenticatable, :trackable
          end
        RUBY
      )

      FileUtils.mkdir_p(File.join(app_path, "db"))
      File.write(
        File.join(app_path, "db/schema.rb"),
        <<~RUBY
          ActiveRecord::Schema[8.0].define(version: 2026_01_01_000000) do
            create_table "users" do |t|
              t.integer "sign_in_count", default: 0, null: false
            end
          end
        RUBY
      )

      detector = described_class.new(app_path: app_path, devise_user_model: "User")
      expect(detector.detect).to eq(["trackable"])
    end
  end
end
