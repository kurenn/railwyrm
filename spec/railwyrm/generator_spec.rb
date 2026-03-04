# frozen_string_literal: true

require "spec_helper"

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
        File.write(
          File.join(app_path, "app/views/layouts/application.html.erb"),
          <<~ERB
            <main class="container mx-auto mt-28 px-5 flex">
              <%= yield %>
            </main>
          ERB
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
      expect(gemfile).to include('gem "claude-on-rails"')

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

      app_layout = File.read(File.join(configuration.app_path, "app/views/layouts/application.html.erb"))
      expect(app_layout).to include("justify-center")
      expect(app_layout).to include("w-full")
      expect(app_layout).to include("min-h-screen")
      expect(app_layout).not_to include("mt-28")
      expect(app_layout).not_to include("container")
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
end
