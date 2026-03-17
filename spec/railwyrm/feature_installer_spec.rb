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

      if command[0] == "bin/rails" && command[1] == "generate" && command[2] == "devise:webauthn:install"
        FileUtils.mkdir_p(File.join(chdir, "config/initializers"))
        File.write(
          File.join(chdir, "config/initializers/webauthn.rb"),
          <<~RUBY
            WebAuthn.configure do |config|
              # config.rp_name = "<App Name>"
              # config.rp_id = "localhost"
              # config.allowed_origins = [ "https://auth.example.com" ]
            end
          RUBY
        )
      end

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

    FileUtils.mkdir_p(File.join(root, "app/controllers"))
    File.write(
      File.join(root, "app/controllers/application_controller.rb"),
      <<~RUBY
        class ApplicationController < ActionController::Base
        end
      RUBY
    )

    FileUtils.mkdir_p(File.join(root, "app/views/layouts"))
    File.write(
      File.join(root, "app/views/layouts/application.html.erb"),
      <<~ERB
        <!DOCTYPE html>
        <html>
          <head>
            <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
          </head>
          <body>
            <%= yield %>
          </body>
        </html>
      ERB
    )

    FileUtils.mkdir_p(File.join(root, "app/views/devise/sessions"))
    File.write(
      File.join(root, "app/views/devise/sessions/new.html.erb"),
      <<~ERB
        <%= form_for(resource, as: resource_name, url: session_path(resource_name)) do |f| %>
          <%= f.email_field :email %>
        <% end %>

        <% if devise_mapping.registerable? %>
          <%= link_to "Sign up", new_registration_path(resource_name) %>
        <% end %>
      ERB
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

      routes = File.read(File.join(app_path, "config/routes.rb"))
      expect(routes).to include('devise_for :users, controllers: { passkeys: "users/passkeys" }')

      passkeys_controller = File.read(File.join(app_path, "app/controllers/users/passkeys_controller.rb"))
      expect(passkeys_controller).to include("rescue_from JSON::ParserError")

      passkeys_view = File.read(File.join(app_path, "app/views/devise/passkeys/new.html.erb"))
      expect(passkeys_view).to include("passkey_creation_form_for")

      session_view = File.read(File.join(app_path, "app/views/devise/sessions/new.html.erb"))
      expect(session_view).to include("login_with_passkey_button")

      app_layout = File.read(File.join(app_path, "app/views/layouts/application.html.erb"))
      expect(app_layout).to include('javascript_include_tag "devise/webauthn", type: "module"')

      app_controller = File.read(File.join(app_path, "app/controllers/application_controller.rb"))
      expect(app_controller).to include("def after_sign_in_path_for")

      webauthn_initializer = File.read(File.join(app_path, "config/initializers/webauthn.rb"))
      expect(webauthn_initializer).to include('config.rp_name = ENV.fetch("WEBAUTHN_RP_NAME", "')
      expect(webauthn_initializer).to include('config.rp_id = ENV.fetch("WEBAUTHN_RP_ID", "localhost")')
      expect(webauthn_initializer).to include('config.allowed_origins = ENV.fetch("WEBAUTHN_ALLOWED_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000").split(",").map(&:strip).reject(&:empty?)')
      expect(webauthn_initializer).not_to include("<App Name>")

      env_example = File.read(File.join(app_path, ".env.example"))
      expect(env_example).to include("WEBAUTHN_RP_NAME=")
      expect(env_example).to include("WEBAUTHN_RP_ID=localhost")
      expect(env_example).to include("WEBAUTHN_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000")

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

  it "installs ci feature into an existing app" do
    Dir.mktmpdir do |app_path|
      build_minimal_app!(app_path)

      shell = FeatureInstallerFakeShell.new
      ui = Railwyrm::UI::Buffer.new
      installer = described_class.new(app_path: app_path, ui: ui, shell: shell)

      installed = installer.install!(["ci"])
      expect(installed).to eq(["ci"])

      workflow_path = File.join(app_path, ".github/workflows/ci.yml")
      expect(File).to exist(workflow_path)
      workflow = File.read(workflow_path)
      expect(workflow).to include("name: CI")
      expect(workflow).to include("bundle exec rspec")
      expect(workflow).to include("bundle exec rubocop")
      expect(workflow).to include("bundle exec brakeman")

      feature_manifest = YAML.safe_load(
        File.read(File.join(app_path, ".railwyrm/features.yml")),
        permitted_classes: [],
        aliases: false
      )
      expect(feature_manifest.fetch("features")).to eq(["ci"])
    end
  end

  it "installs quality feature and dependency changes into an existing app" do
    Dir.mktmpdir do |app_path|
      build_minimal_app!(app_path)

      shell = FeatureInstallerFakeShell.new
      ui = Railwyrm::UI::Buffer.new
      installer = described_class.new(app_path: app_path, ui: ui, shell: shell)

      installed = installer.install!(["quality"])
      expect(installed).to eq(%w[ci quality])

      gemfile = File.read(File.join(app_path, "Gemfile"))
      expect(gemfile).to include('gem "brakeman"')
      expect(gemfile).to include('gem "rubocop"')
      expect(gemfile).to include('gem "rubocop-rails"')
      expect(gemfile).to include('gem "bullet"')

      workflow_path = File.join(app_path, ".github/workflows/ci.yml")
      expect(File).to exist(workflow_path)

      development_config = File.read(File.join(app_path, "config/environments/development.rb"))
      expect(development_config).to include("Bullet.enable = true")
      expect(development_config).to include("Bullet.alert = true")
      expect(development_config).to include("Bullet.bullet_logger = true")
      expect(development_config).to include("Bullet.rails_logger = true")

      feature_manifest = YAML.safe_load(
        File.read(File.join(app_path, ".railwyrm/features.yml")),
        permitted_classes: [],
        aliases: false
      )
      expect(feature_manifest.fetch("features")).to eq(%w[ci quality])

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to include("bundle install")
    end
  end
end
