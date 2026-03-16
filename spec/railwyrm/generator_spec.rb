# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe Railwyrm::Generator do
  class FakeShell
    attr_reader :commands

    def initialize
      @commands = []
    end

    def run!(*command, chdir: nil)
      commands << { command: command, chdir: chdir }

      if command[0] == "rails" && command[1] == "new"
        app_name = command[2]
        app_path = File.join(chdir, app_name)
        FileUtils.mkdir_p(app_path)
        File.write(File.join(app_path, "Gemfile"), "source \"https://rubygems.org\"\n")
        FileUtils.mkdir_p(File.join(app_path, "app/views/layouts"))
        FileUtils.mkdir_p(File.join(app_path, "app/controllers"))
        FileUtils.mkdir_p(File.join(app_path, "config/initializers"))
        FileUtils.mkdir_p(File.join(app_path, "config/environments"))
        FileUtils.mkdir_p(File.join(app_path, "config/locales"))
        File.write(
          File.join(app_path, "app/views/layouts/application.html.erb"),
          <<~ERB
            <!DOCTYPE html>
            <html>
              <head>
                <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
              </head>
              <body>
                <main class="container mx-auto mt-28 px-5 flex">
                  <%= yield %>
                </main>
              </body>
            </html>
          ERB
        )
        File.write(
          File.join(app_path, "app/controllers/application_controller.rb"),
          <<~RUBY
            class ApplicationController < ActionController::Base
            end
          RUBY
        )
        File.write(
          File.join(app_path, "config/routes.rb"),
          <<~RUBY
            Rails.application.routes.draw do
              devise_for :users
            end
          RUBY
        )
        File.write(
          File.join(app_path, "config/initializers/devise.rb"),
          <<~RUBY
            Devise.setup do |config|
              # config.paranoid = true
            end
          RUBY
        )
        File.write(
          File.join(app_path, "config/environments/development.rb"),
          <<~RUBY
            Rails.application.configure do
            end
          RUBY
        )
      end

      if command[0] == "bin/rails" && command[1] == "generate" && command[2] == "devise" && command[3]
        model_name = command[3]
        model_file = File.join(chdir, "app/models/#{model_name.downcase}.rb")
        FileUtils.mkdir_p(File.dirname(model_file))
        File.write(
          model_file,
          <<~RUBY
            class #{model_name} < ApplicationRecord
              # Include default devise modules. Others available are:
              # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
              devise :database_authenticatable, :registerable,
                     :recoverable, :rememberable, :validatable
            end
          RUBY
        )

        migration_file = File.join(chdir, "db/migrate/20260101000000_devise_create_#{model_name.downcase}s.rb")
        FileUtils.mkdir_p(File.dirname(migration_file))
        File.write(
          migration_file,
          <<~RUBY
            class DeviseCreate#{model_name}s < ActiveRecord::Migration[8.1]
              def change; end
            end
          RUBY
        )
      end

      if command[0] == "bin/rails" && command[1] == "generate" && command[2] == "devise:passwordless:install"
        FileUtils.mkdir_p(File.join(chdir, "app/views/devise/mailer"))
        File.write(
          File.join(chdir, "app/views/devise/mailer/magic_link.html.erb"),
          "<p>Magic link</p>\n"
        )
      end

      if command[0] == "bin/rails" && command[1] == "generate" && command[2] == "devise:webauthn:install"
        migration_file = File.join(chdir, "db/migrate/20260102000000_devise_webauthn_create_credentials.rb")
        FileUtils.mkdir_p(File.dirname(migration_file))
        File.write(
          migration_file,
          <<~RUBY
            class DeviseWebauthnCreateCredentials < ActiveRecord::Migration[8.1]
              def change; end
            end
          RUBY
        )

        FileUtils.mkdir_p(File.join(chdir, "config/initializers"))
        File.write(
          File.join(chdir, "config/initializers/webauthn.rb"),
          <<~RUBY
            WebAuthn.configure do |config|
              # config.rp_name = "Example Inc."
              # config.rp_id = "localhost"
              # config.allowed_origins = [ "https://auth.example.com" ]
            end
          RUBY
        )
      end

      true
    end
  end

  it "updates Gemfile and schedules all expected setup commands" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(name: "forge_test", workspace: workspace)
      shell = FakeShell.new
      ui = Railwyrm::UI::Buffer.new

      described_class.new(configuration, ui: ui, shell: shell).run!

      gemfile = File.read(File.join(configuration.app_path, "Gemfile"))
      expect(gemfile).to include('gem "devise"')
      expect(gemfile).to include('gem "untitled_ui", github: "coba-ai/untitled.ui", branch: "main"')
      expect(gemfile).to include('gem "rspec-rails"')
      expect(gemfile).to include('gem "dotenv-rails"')
      expect(gemfile).to include('gem "ruby-lsp", require: false')
      expect(gemfile).to include('gem "brakeman", require: false')
      expect(gemfile).to include('gem "rubocop", require: false')
      expect(gemfile).to include('gem "rubocop-rails", require: false')
      expect(gemfile).to include('gem "bullet"')
      expect(gemfile).to include('gem "claude-on-rails", github: "kurenn/claude-on-rails", branch: "main"')

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to include("bundle install")
      expect(executed).to include("./bin/rails tailwindcss:install")
      expect(executed).to include("bin/rails generate untitled_ui:install")
      expect(executed).to include("bin/rails generate devise User")
      expect(executed).to include("bin/rails generate claude_on_rails:swarm --force")
      expect(executed).to include("bin/rails db:migrate")

      session_view = File.read(File.join(configuration.app_path, "app/views/devise/sessions/new.html.erb"))
      expect(session_view).to include("Ui::Input::Component")
      expect(session_view).to include("Ui::Button::Component")
      expect(session_view).to include("Ui::Checkbox::Component")
      expect(session_view).not_to include("Google")

      registration_view = File.read(File.join(configuration.app_path, "app/views/devise/registrations/new.html.erb"))
      expect(registration_view).to include("Ui::Input::Component")
      expect(registration_view).to include("Create account")
      expect(registration_view).to include("Railwyrm Access")

      password_view = File.read(File.join(configuration.app_path, "app/views/devise/passwords/new.html.erb"))
      expect(password_view).to include("Send reset instructions")

      development_config = File.read(File.join(configuration.app_path, "config/environments/development.rb"))
      expect(development_config).to include("config.after_initialize do")
      expect(development_config).to include("Bullet.enable = true")
      expect(development_config).to include("Bullet.rails_logger = true")

      ci_workflow = File.read(File.join(configuration.app_path, ".github/workflows/ci.yml"))
      expect(ci_workflow).to include("name: CI")
      expect(ci_workflow).to include("bundle exec rspec")
      expect(ci_workflow).to include("bundle exec rubocop")
      expect(ci_workflow).to include("bundle exec brakeman")

      app_layout = File.read(File.join(configuration.app_path, "app/views/layouts/application.html.erb"))
      expect(app_layout).to include("justify-center")
      expect(app_layout).to include("w-full")
      expect(app_layout).to include("min-h-screen")
      expect(app_layout).not_to include("mt-28")
      expect(app_layout).not_to include("container")

      feature_manifest = YAML.safe_load(
        File.read(File.join(configuration.app_path, ".railwyrm/features.yml")),
        permitted_classes: [],
        aliases: false
      )
      expect(feature_manifest.fetch("features")).to eq(["ci"])
    end
  end

  it "applies the selected devise auth template pack" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(
        name: "split_layout_app",
        workspace: workspace,
        sign_in_layout: "split_mockup_quote"
      )
      shell = FakeShell.new
      ui = Railwyrm::UI::Buffer.new

      described_class.new(configuration, ui: ui, shell: shell).run!

      expected_views = %w[
        sessions/new
        registrations/new
        registrations/edit
        passwords/new
        passwords/edit
        confirmations/new
        unlocks/new
      ]

      expected_views.each do |view_name|
        expect(File).to exist(File.join(configuration.app_path, "app/views/devise/#{view_name}.html.erb"))
      end

      session_view = File.read(File.join(configuration.app_path, "app/views/devise/sessions/new.html.erb"))
      expect(session_view).to include("Trusted by teams")
      expect(session_view).to include("Ui::Input::Component")
      expect(session_view).not_to include("Google")

      registration_view = File.read(File.join(configuration.app_path, "app/views/devise/registrations/new.html.erb"))
      expect(registration_view).to include("Trusted by teams")
      expect(registration_view).to include("Create account")
    end
  end

  it "does not write files in dry run mode" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(name: "dry_test", workspace: workspace, dry_run: true)
      ui = Railwyrm::UI::Buffer.new

      described_class.new(configuration, ui: ui).run!

      expect(Dir.exist?(configuration.app_path)).to be(false)
    end
  end

  it "enables devise confirmable when requested" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(
        name: "confirmable_app",
        workspace: workspace,
        devise_confirmable: true
      )
      shell = FakeShell.new
      ui = Railwyrm::UI::Buffer.new

      described_class.new(configuration, ui: ui, shell: shell).run!

      user_model = File.read(File.join(configuration.app_path, "app/models/user.rb"))
      expect(user_model).to include("devise :confirmable, :database_authenticatable")

      migration = Dir.glob(File.join(configuration.app_path, "db/migrate/*_add_confirmable_to_users.rb")).first
      expect(migration).not_to be_nil
      migration_content = File.read(migration)
      expect(migration_content).to include("add_column :users, :confirmation_token, :string")
      expect(migration_content).to include("add_index :users, :confirmation_token, unique: true")

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed.count { |line| line == "bin/rails db:migrate" }).to eq(2)
    end
  end

  it "enables devise lockable and timeoutable when requested" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(
        name: "lockable_timeoutable_app",
        workspace: workspace,
        devise_lockable: true,
        devise_timeoutable: true
      )
      shell = FakeShell.new
      ui = Railwyrm::UI::Buffer.new

      described_class.new(configuration, ui: ui, shell: shell).run!

      user_model = File.read(File.join(configuration.app_path, "app/models/user.rb"))
      expect(user_model).to include("devise :lockable, :timeoutable, :database_authenticatable")

      migration = Dir.glob(File.join(configuration.app_path, "db/migrate/*_add_lockable_to_users.rb")).first
      expect(migration).not_to be_nil
      migration_content = File.read(migration)
      expect(migration_content).to include("add_column :users, :failed_attempts, :integer, default: 0, null: false")
      expect(migration_content).to include("add_index :users, :unlock_token, unique: true")

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed.count { |line| line == "bin/rails db:migrate" }).to eq(2)
    end
  end

  it "enables devise trackable when requested" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(
        name: "trackable_app",
        workspace: workspace,
        devise_trackable: true
      )
      shell = FakeShell.new
      ui = Railwyrm::UI::Buffer.new

      described_class.new(configuration, ui: ui, shell: shell).run!

      user_model = File.read(File.join(configuration.app_path, "app/models/user.rb"))
      expect(user_model).to include("devise :trackable, :database_authenticatable")

      migration = Dir.glob(File.join(configuration.app_path, "db/migrate/*_add_trackable_to_users.rb")).first
      expect(migration).not_to be_nil
      migration_content = File.read(migration)
      expect(migration_content).to include("add_column :users, :sign_in_count, :integer, default: 0, null: false")
      expect(migration_content).to include("add_column :users, :current_sign_in_at, :datetime")
      expect(migration_content).to include("add_column :users, :last_sign_in_at, :datetime")
      expect(migration_content).to include("add_column :users, :current_sign_in_ip, :string")
      expect(migration_content).to include("add_column :users, :last_sign_in_ip, :string")

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed.count { |line| line == "bin/rails db:migrate" }).to eq(2)
    end
  end

  it "installs magic-link authentication when requested" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(
        name: "magic_link_app",
        workspace: workspace,
        devise_magic_link: true
      )
      shell = FakeShell.new
      ui = Railwyrm::UI::Buffer.new

      described_class.new(configuration, ui: ui, shell: shell).run!

      gemfile = File.read(File.join(configuration.app_path, "Gemfile"))
      expect(gemfile).to include('gem "devise-passwordless"')

      user_model = File.read(File.join(configuration.app_path, "app/models/user.rb"))
      expect(user_model).to include(":magic_link_authenticatable")
      expect(user_model).to include(":trackable")

      routes = File.read(File.join(configuration.app_path, "config/routes.rb"))
      expect(routes).to include("namespace :passwordless do")
      expect(routes).to include('devise_for :users, controllers: { sessions: "devise/passwordless/sessions" }')

      passwordless_view = File.read(File.join(configuration.app_path, "app/views/devise/passwordless/sessions/new.html.erb"))
      expect(passwordless_view).to include("Email me a magic link")
      expect(passwordless_view).to include("Send magic link")
      expect(passwordless_view).to include('passwordless_#{resource_name}_session_path')

      passwordless_mail_text = File.read(File.join(configuration.app_path, "app/views/devise/mailer/magic_link.text.erb"))
      expect(passwordless_mail_text).to include("Use this magic link to sign in")
      expect(passwordless_mail_text).to include("magic_link_url")

      session_view = File.read(File.join(configuration.app_path, "app/views/devise/sessions/new.html.erb"))
      expect(session_view).to include("Email me a sign-in link")

      devise_initializer = File.read(File.join(configuration.app_path, "config/initializers/devise.rb"))
      expect(devise_initializer).to include("config.paranoid = true")

      development_config = File.read(File.join(configuration.app_path, "config/environments/development.rb"))
      expect(development_config).to include("config.action_mailer.delivery_method = :file")
      expect(development_config).to include('config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }')

      feature_manifest = YAML.safe_load(
        File.read(File.join(configuration.app_path, ".railwyrm/features.yml")),
        permitted_classes: [],
        aliases: false
      )
      expect(feature_manifest.fetch("features")).to eq(%w[ci trackable magic_link])

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to include("bin/rails generate devise:passwordless:install --force")
      expect(executed.count { |line| line == "bin/rails db:migrate" }).to eq(2)
    end
  end

  it "installs passkeys authentication when requested" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(
        name: "passkeys_app",
        workspace: workspace,
        devise_passkeys: true
      )
      shell = FakeShell.new
      ui = Railwyrm::UI::Buffer.new

      described_class.new(configuration, ui: ui, shell: shell).run!

      gemfile = File.read(File.join(configuration.app_path, "Gemfile"))
      expect(gemfile).to include('gem "devise-webauthn"')

      user_model = File.read(File.join(configuration.app_path, "app/models/user.rb"))
      expect(user_model).to include(":passkey_authenticatable")

      feature_manifest = YAML.safe_load(
        File.read(File.join(configuration.app_path, ".railwyrm/features.yml")),
        permitted_classes: [],
        aliases: false
      )
      expect(feature_manifest.fetch("features")).to eq(%w[ci passkeys])

      routes = File.read(File.join(configuration.app_path, "config/routes.rb"))
      expect(routes).to include('devise_for :users, controllers: { passkeys: "users/passkeys" }')

      passkeys_controller = File.read(File.join(configuration.app_path, "app/controllers/users/passkeys_controller.rb"))
      expect(passkeys_controller).to include("class PasskeysController < Devise::PasskeysController")
      expect(passkeys_controller).to include("rescue_from JSON::ParserError")

      passkeys_view = File.read(File.join(configuration.app_path, "app/views/devise/passkeys/new.html.erb"))
      expect(passkeys_view).to include("passkey_creation_form_for")
      expect(passkeys_view).to include("Create passkey now")

      session_view = File.read(File.join(configuration.app_path, "app/views/devise/sessions/new.html.erb"))
      expect(session_view).to include("login_with_passkey_button")

      app_layout = File.read(File.join(configuration.app_path, "app/views/layouts/application.html.erb"))
      expect(app_layout).to include('javascript_include_tag "devise/webauthn", type: "module"')

      webauthn_initializer = File.read(File.join(configuration.app_path, "config/initializers/webauthn.rb"))
      expect(webauthn_initializer).to include('config.rp_name = ENV.fetch("WEBAUTHN_RP_NAME", "Passkeys App")')
      expect(webauthn_initializer).to include('config.rp_id = ENV.fetch("WEBAUTHN_RP_ID", "localhost")')
      expect(webauthn_initializer).to include('config.allowed_origins = ENV.fetch("WEBAUTHN_ALLOWED_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000").split(",").map(&:strip).reject(&:empty?)')
      expect(webauthn_initializer).not_to include("<App Name>")

      env_example = File.read(File.join(configuration.app_path, ".env.example"))
      expect(env_example).to include("WEBAUTHN_RP_NAME=Passkeys App")
      expect(env_example).to include("WEBAUTHN_RP_ID=localhost")
      expect(env_example).to include("WEBAUTHN_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000")

      app_controller = File.read(File.join(configuration.app_path, "app/controllers/application_controller.rb"))
      expect(app_controller).to include("def after_sign_in_path_for")
      expect(app_controller).to include("resource&.respond_to?(:passkeys) && resource.passkeys.none?")

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to include("bin/rails generate devise:webauthn:install --force")
      expect(executed.count { |line| line == "bin/rails db:migrate" }).to eq(2)
    end
  end
end
