# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe Railwyrm::FeatureInstaller do
  class FeatureInstallerFakeShell
    attr_reader :commands

    def initialize
      @commands = []
    end

    def run!(*command, chdir: nil)
      commands << { command: command, chdir: chdir }
      true
    end
  end

  def build_minimal_app!(root)
    File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")

    FileUtils.mkdir_p(File.join(root, "app/models"))
    File.write(
      File.join(root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
          # Include default devise modules. Others available are:
          # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
          devise :database_authenticatable, :registerable,
                 :recoverable, :rememberable, :validatable
        end
      RUBY
    )

    FileUtils.mkdir_p(File.join(root, "config"))
    File.write(
      File.join(root, "config/routes.rb"),
      <<~RUBY
        Rails.application.routes.draw do
          devise_for :users
        end
      RUBY
    )

    FileUtils.mkdir_p(File.join(root, "config/initializers"))
    File.write(
      File.join(root, "config/initializers/devise.rb"),
      <<~RUBY
        Devise.setup do |config|
          # config.paranoid = true
        end
      RUBY
    )

    FileUtils.mkdir_p(File.join(root, "config/environments"))
    File.write(
      File.join(root, "config/environments/development.rb"),
      <<~RUBY
        Rails.application.configure do
        end
      RUBY
    )

    FileUtils.mkdir_p(File.join(root, "db/migrate"))
    File.write(
      File.join(root, "db/migrate/20260101000000_devise_create_users.rb"),
      <<~RUBY
        class DeviseCreateUsers < ActiveRecord::Migration[8.1]
          def change; end
        end
      RUBY
    )
  end

  it "installs magic_link and required dependency changes" do
    Dir.mktmpdir do |app_path|
      build_minimal_app!(app_path)

      shell = FeatureInstallerFakeShell.new
      ui = Railwyrm::UI::Buffer.new
      installer = described_class.new(app_path: app_path, ui: ui, shell: shell)

      installed = installer.install!(["magic_link"])
      expect(installed).to eq(%w[trackable magic_link])

      gemfile = File.read(File.join(app_path, "Gemfile"))
      expect(gemfile).to include('gem "devise-passwordless"')

      user_model = File.read(File.join(app_path, "app/models/user.rb"))
      expect(user_model).to include(":trackable")
      expect(user_model).to include(":magic_link_authenticatable")

      routes = File.read(File.join(app_path, "config/routes.rb"))
      expect(routes).to include("namespace :passwordless do")
      expect(routes).to include('devise_for :users, controllers: { sessions: "devise/passwordless/sessions" }')

      initializer = File.read(File.join(app_path, "config/initializers/devise.rb"))
      expect(initializer).to include("config.paranoid = true")

      development = File.read(File.join(app_path, "config/environments/development.rb"))
      expect(development).to include("config.action_mailer.delivery_method = :file")
      expect(development).to include('config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }')

      mailer_text = File.read(File.join(app_path, "app/views/devise/mailer/magic_link.text.erb"))
      expect(mailer_text).to include("Use this magic link to sign in")

      feature_manifest = YAML.safe_load(
        File.read(File.join(app_path, ".railwyrm/features.yml")),
        permitted_classes: [],
        aliases: false
      )
      expect(feature_manifest.fetch("features")).to eq(%w[trackable magic_link])

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to include("bundle install")
      expect(executed).to include("bin/rails db:migrate")
      expect(executed).to include("bin/rails generate devise:passwordless:install --force")
    end
  end

  it "raises when app path does not exist" do
    shell = FeatureInstallerFakeShell.new
    ui = Railwyrm::UI::Buffer.new
    installer = described_class.new(app_path: "/tmp/does-not-exist-#{Process.pid}", ui: ui, shell: shell)

    expect do
      installer.install!(["trackable"])
    end.to raise_error(Railwyrm::InvalidConfiguration, /Rails app path not found/)
  end

  it "skips install when requested features are already installed" do
    Dir.mktmpdir do |app_path|
      build_minimal_app!(app_path)

      shell = FeatureInstallerFakeShell.new
      ui = Railwyrm::UI::Buffer.new
      installer = described_class.new(app_path: app_path, ui: ui, shell: shell)

      installer.install!(["magic_link"])
      shell.commands.clear

      installed = installer.install!(["magic_link"])
      expect(installed).to eq(%w[trackable magic_link])

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to eq([])
    end
  end

  it "installs passkeys feature into an existing app" do
    Dir.mktmpdir do |app_path|
      build_minimal_app!(app_path)

      shell = FeatureInstallerFakeShell.new
      ui = Railwyrm::UI::Buffer.new
      installer = described_class.new(app_path: app_path, ui: ui, shell: shell)

      installed = installer.install!(["passkeys"])
      expect(installed).to eq(["passkeys"])

      gemfile = File.read(File.join(app_path, "Gemfile"))
      expect(gemfile).to include('gem "devise-webauthn"')

      user_model = File.read(File.join(app_path, "app/models/user.rb"))
      expect(user_model).to include(":passkey_authenticatable")

      feature_manifest = YAML.safe_load(
        File.read(File.join(app_path, ".railwyrm/features.yml")),
        permitted_classes: [],
        aliases: false
      )
      expect(feature_manifest.fetch("features")).to eq(["passkeys"])

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to include("bundle install")
      expect(executed).to include("bin/rails generate devise:webauthn:install --force")
      expect(executed).to include("bin/rails db:migrate")
    end
  end
end
