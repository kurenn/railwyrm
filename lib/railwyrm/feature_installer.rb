# frozen_string_literal: true

require "fileutils"

module Railwyrm
  class FeatureInstaller
    OPTIONAL_DEVISE_MODULES = %w[confirmable lockable timeoutable trackable].freeze

    def initialize(app_path:, ui:, shell:, dry_run: false, devise_user_model: "User")
      @app_path = File.expand_path(app_path)
      @ui = ui
      @shell = shell
      @dry_run = dry_run
      @devise_user_model = devise_user_model.to_s.strip.empty? ? "User" : devise_user_model.to_s.strip
    end

    def install!(feature_names)
      requested_features = FeatureRegistry.resolve(feature_names)
      ensure_app_path!

      ui.headline("Installing features in #{app_path}")
      ui.info("Requested features: #{requested_features.join(', ')}")

      tracked_features = feature_state.tracked_features
      detected_features = feature_detector.detect
      sync_untracked_features!(tracked_features, detected_features)
      tracked_features = feature_state.tracked_features unless dry_run

      drift = tracked_features - detected_features
      unless drift.empty?
        ui.warn("Tracked but not detected in app: #{drift.join(', ')}")
        ui.warn("Railwyrm will attempt reinstallation if these are requested.")
      end

      features = requested_features - detected_features
      if features.empty?
        ui.success("All requested features are already installed.")
        return requested_features
      end

      ui.info("Applying features: #{features.join(', ')}")

      gems_changed = ensure_feature_gems!(features)
      if gems_changed
        ui.step("Install bundle for feature gems") do
          shell.run!("bundle", "install", chdir: app_path)
        end
      end

      module_features = features & OPTIONAL_DEVISE_MODULES
      unless module_features.empty?
        ui.step("Enable Devise modules: #{module_features.join(', ')}") do
          enable_optional_devise_modules!(module_features)
        end
      end

      if features.include?("magic_link")
        ui.step("Install magic-link authentication") do
          enable_magic_link_authentication!
        end
      end

      if features.include?("passkeys")
        ui.step("Install passkeys authentication") do
          enable_passkeys_authentication!
        end
      end

      feature_state.mark_installed!(requested_features)

      ui.success("Feature install complete: #{requested_features.join(', ')}")
      requested_features
    end

    private

    attr_reader :app_path, :ui, :shell, :dry_run, :devise_user_model

    def ensure_app_path!
      return if dry_run

      raise InvalidConfiguration, "Rails app path not found: #{app_path}" unless Dir.exist?(app_path)

      gemfile_path = File.join(app_path, "Gemfile")
      raise InvalidConfiguration, "Gemfile not found at #{gemfile_path}" unless File.exist?(gemfile_path)
    end

    def sync_untracked_features!(tracked_features, detected_features)
      untracked = detected_features - tracked_features
      return if untracked.empty?

      ui.info("Detected installed but untracked features: #{untracked.join(', ')}")
      feature_state.mark_installed!(untracked)
      ui.info("Feature manifest synchronized with detected app state.") unless dry_run
    end

    def ensure_feature_gems!(features)
      entries = []

      if features.include?("magic_link")
        entries << {
          marker: 'gem "devise-passwordless"',
          snippet: 'gem "devise-passwordless"'
        }
      end

      if features.include?("passkeys")
        entries << {
          marker: 'gem "devise-webauthn"',
          snippet: 'gem "devise-webauthn"'
        }
      end

      return false if entries.empty?

      gemfile_path = File.join(app_path, "Gemfile")
      gemfile = File.exist?(gemfile_path) ? File.read(gemfile_path) : ""
      additions = entries.each_with_object([]) do |entry, snippets|
        snippets << entry[:snippet] unless gemfile.include?(entry[:marker])
      end

      return false if additions.empty?

      if dry_run
        ui.info("Dry run enabled: Gemfile update skipped.")
        return true
      end

      updated = "#{gemfile.rstrip}\n\n#{additions.join("\n\n")}\n"
      File.write(gemfile_path, updated)
      ui.success("Gemfile updated for selected features.")
      true
    end

    def enable_optional_devise_modules!(module_names)
      if dry_run
        ui.info("Dry run enabled: optional Devise module setup skipped.")
        return
      end

      model_relative_path = "app/models/#{underscore(devise_user_model)}.rb"
      model_path = File.join(app_path, model_relative_path)
      raise InvalidConfiguration, "Devise model file not found: #{model_relative_path}" unless File.exist?(model_path)

      model_content = File.read(model_path)
      updated_model = inject_devise_modules_into_model(model_content, module_names, model_relative_path)
      File.write(model_path, updated_model) unless updated_model == model_content

      migration_created = false
      migration_created ||= ensure_confirmable_migration! if module_names.include?("confirmable")
      migration_created ||= ensure_lockable_migration! if module_names.include?("lockable")
      migration_created ||= ensure_trackable_migration! if module_names.include?("trackable")
      shell.run!("bin/rails", "db:migrate", chdir: app_path) if migration_created
    end

    def enable_magic_link_authentication!
      if dry_run
        ui.info("Dry run enabled: magic-link setup skipped.")
        return
      end

      shell.run!("bin/rails", "generate", "devise:passwordless:install", "--force", chdir: app_path)

      resource_key = pluralize(underscore(devise_user_model))
      ensure_model_includes_magic_link_authenticatable!
      ensure_passwordless_routes!(resource_key)
      ensure_passwordless_session_template!
      ensure_passwordless_mailer_templates!
      ensure_devise_paranoid_mode!
      ensure_development_mail_file_delivery!
    end

    def enable_passkeys_authentication!
      if dry_run
        ui.info("Dry run enabled: passkeys setup skipped.")
        return
      end

      shell.run!("bin/rails", "generate", "devise:webauthn:install", "--force", chdir: app_path)
      ensure_model_includes_passkey_authenticatable!
      shell.run!("bin/rails", "db:migrate", chdir: app_path)
    end

    def ensure_model_includes_magic_link_authenticatable!
      model_relative_path = "app/models/#{underscore(devise_user_model)}.rb"
      model_path = File.join(app_path, model_relative_path)
      raise InvalidConfiguration, "Devise model file not found: #{model_relative_path}" unless File.exist?(model_path)

      model_content = File.read(model_path)
      updated = inject_devise_modules_into_model(model_content, ["magic_link_authenticatable"], model_relative_path)
      File.write(model_path, updated)
    end

    def ensure_model_includes_passkey_authenticatable!
      model_relative_path = "app/models/#{underscore(devise_user_model)}.rb"
      model_path = File.join(app_path, model_relative_path)
      raise InvalidConfiguration, "Devise model file not found: #{model_relative_path}" unless File.exist?(model_path)

      model_content = File.read(model_path)
      updated = inject_devise_modules_into_model(model_content, ["passkey_authenticatable"], model_relative_path)
      File.write(model_path, updated)
    end

    def ensure_passwordless_routes!(resource_key)
      routes_path = File.join(app_path, "config/routes.rb")
      raise InvalidConfiguration, "Routes file not found: #{routes_path}" unless File.exist?(routes_path)

      routes_content = File.read(routes_path)
      route_snippet = "controllers: { sessions: \"devise/passwordless/sessions\" }"
      return if routes_content.include?(route_snippet)

      insertion = <<~RUBY

          namespace :passwordless do
            devise_for :#{resource_key}, controllers: { sessions: "devise/passwordless/sessions" }
          end
      RUBY
      updated = routes_content.sub(/\nend\s*\z/, "#{insertion}\nend\n")
      raise InvalidConfiguration, "Unable to inject passwordless routes into #{routes_path}" if updated == routes_content

      File.write(routes_path, updated)
    end

    def ensure_passwordless_session_template!
      source = File.join(
        template_root,
        "devise",
        "passwordless",
        "sessions",
        "new.html.erb"
      )
      raise InvalidConfiguration, "Passwordless session template missing: #{source}" unless File.exist?(source)

      destination = File.join(app_path, "app/views/devise/passwordless/sessions/new.html.erb")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def ensure_passwordless_mailer_templates!
      source = File.join(
        template_root,
        "devise",
        "passwordless",
        "mailer",
        "magic_link.text.erb"
      )
      raise InvalidConfiguration, "Passwordless mailer template missing: #{source}" unless File.exist?(source)

      destination = File.join(app_path, "app/views/devise/mailer/magic_link.text.erb")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def ensure_devise_paranoid_mode!
      initializer_path = File.join(app_path, "config/initializers/devise.rb")
      return unless File.exist?(initializer_path)

      content = File.read(initializer_path)
      updated = if content.match?(/^\s*#?\s*config\.paranoid\s*=.*$/)
                  content.gsub(/^\s*#?\s*config\.paranoid\s*=.*$/, "  config.paranoid = true")
                else
                  content.sub(/Devise\.setup do \|config\|\n/, "Devise.setup do |config|\n  config.paranoid = true\n")
                end
      File.write(initializer_path, updated) unless updated == content
    end

    def ensure_development_mail_file_delivery!
      development_path = File.join(app_path, "config/environments/development.rb")
      return unless File.exist?(development_path)

      content = File.read(development_path)
      updated = content

      delivery_method_line = "  config.action_mailer.delivery_method = :file"
      file_settings_line = '  config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }'

      if updated.match?(/^\s*#?\s*config\.action_mailer\.delivery_method\s*=.*$/)
        updated = updated.gsub(/^\s*#?\s*config\.action_mailer\.delivery_method\s*=.*$/, delivery_method_line)
      elsif !updated.include?(delivery_method_line)
        updated = updated.sub(/Rails\.application\.configure do\s*\n/, "Rails.application.configure do\n#{delivery_method_line}\n")
      end

      if updated.match?(/^\s*#?\s*config\.action_mailer\.file_settings\s*=.*$/)
        updated = updated.gsub(/^\s*#?\s*config\.action_mailer\.file_settings\s*=.*$/, file_settings_line)
      elsif !updated.include?(file_settings_line)
        updated = updated.sub("#{delivery_method_line}\n", "#{delivery_method_line}\n#{file_settings_line}\n")
      end

      File.write(development_path, updated) unless updated == content
    end

    def inject_devise_modules_into_model(model_content, module_names, model_relative_path)
      lines = model_content.lines
      declaration_start, declaration_end = find_devise_declaration_range(lines, model_relative_path)
      existing_modules = lines[declaration_start..declaration_end].join.scan(/:([a-z_]+)/).flatten
      missing = module_names.reject { |mod| existing_modules.include?(mod) }
      return model_content if missing.empty?

      first_line = lines[declaration_start]
      indentation = first_line[/^\s*/]
      modules = first_line.sub(/^\s*devise\s+/, "")
      missing_prefix = missing.map { |mod| ":#{mod}" }.join(", ")
      lines[declaration_start] = "#{indentation}devise #{missing_prefix}, #{modules}"
      updated = lines.join

      if updated == model_content
        raise InvalidConfiguration, "Could not update Devise module declaration in #{model_relative_path}"
      end

      updated
    end

    def find_devise_declaration_range(lines, model_relative_path)
      declaration_start = lines.index { |line| line.match?(/^\s*devise\s+/) }
      if declaration_start.nil?
        raise InvalidConfiguration, "Could not find Devise module declaration in #{model_relative_path}"
      end

      declaration_end = declaration_start
      while declaration_end + 1 < lines.length && lines[declaration_end].rstrip.end_with?(",")
        declaration_end += 1
      end

      [declaration_start, declaration_end]
    end

    def ensure_confirmable_migration!
      migration_dir = File.join(app_path, "db/migrate")
      FileUtils.mkdir_p(migration_dir)

      table_name = pluralize(underscore(devise_user_model))
      existing = Dir.glob(File.join(migration_dir, "*_add_confirmable_to_#{table_name}.rb")).sort.last
      if existing
        ui.info("Confirmable migration already exists: #{File.basename(existing)}")
        return false
      end

      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      migration_filename = "#{timestamp}_add_confirmable_to_#{table_name}.rb"
      migration_path = File.join(migration_dir, migration_filename)
      migration_class = "AddConfirmableTo#{camelize(table_name)}"

      File.write(
        migration_path,
        <<~RUBY
          class #{migration_class} < ActiveRecord::Migration[#{migration_version}]
            def change
              add_column :#{table_name}, :confirmation_token, :string
              add_column :#{table_name}, :confirmed_at, :datetime
              add_column :#{table_name}, :confirmation_sent_at, :datetime
              add_column :#{table_name}, :unconfirmed_email, :string
              add_index :#{table_name}, :confirmation_token, unique: true
            end
          end
        RUBY
      )
      true
    end

    def ensure_lockable_migration!
      migration_dir = File.join(app_path, "db/migrate")
      FileUtils.mkdir_p(migration_dir)

      table_name = pluralize(underscore(devise_user_model))
      existing = Dir.glob(File.join(migration_dir, "*_add_lockable_to_#{table_name}.rb")).sort.last
      if existing
        ui.info("Lockable migration already exists: #{File.basename(existing)}")
        return false
      end

      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      migration_filename = "#{timestamp}_add_lockable_to_#{table_name}.rb"
      migration_path = File.join(migration_dir, migration_filename)
      migration_class = "AddLockableTo#{camelize(table_name)}"

      File.write(
        migration_path,
        <<~RUBY
          class #{migration_class} < ActiveRecord::Migration[#{migration_version}]
            def change
              add_column :#{table_name}, :failed_attempts, :integer, default: 0, null: false
              add_column :#{table_name}, :unlock_token, :string
              add_column :#{table_name}, :locked_at, :datetime
              add_index :#{table_name}, :unlock_token, unique: true
            end
          end
        RUBY
      )
      true
    end

    def ensure_trackable_migration!
      migration_dir = File.join(app_path, "db/migrate")
      FileUtils.mkdir_p(migration_dir)

      table_name = pluralize(underscore(devise_user_model))
      existing = Dir.glob(File.join(migration_dir, "*_add_trackable_to_#{table_name}.rb")).sort.last
      if existing
        ui.info("Trackable migration already exists: #{File.basename(existing)}")
        return false
      end

      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      migration_filename = "#{timestamp}_add_trackable_to_#{table_name}.rb"
      migration_path = File.join(migration_dir, migration_filename)
      migration_class = "AddTrackableTo#{camelize(table_name)}"

      File.write(
        migration_path,
        <<~RUBY
          class #{migration_class} < ActiveRecord::Migration[#{migration_version}]
            def change
              add_column :#{table_name}, :sign_in_count, :integer, default: 0, null: false
              add_column :#{table_name}, :current_sign_in_at, :datetime
              add_column :#{table_name}, :last_sign_in_at, :datetime
              add_column :#{table_name}, :current_sign_in_ip, :string
              add_column :#{table_name}, :last_sign_in_ip, :string
            end
          end
        RUBY
      )
      true
    end

    def migration_version
      Dir.glob(File.join(app_path, "db/migrate/*.rb")).sort.each do |path|
        match = File.read(path).match(/ActiveRecord::Migration\[(\d+\.\d+)\]/)
        return match[1] if match
      end

      "8.0"
    end

    def template_root
      File.join(File.expand_path("..", __dir__), "railwyrm", "templates")
    end

    def feature_state
      @feature_state ||= FeatureState.new(app_path: app_path, ui: ui, dry_run: dry_run)
    end

    def feature_detector
      @feature_detector ||= FeatureDetector.new(app_path: app_path, devise_user_model: devise_user_model)
    end

    def underscore(value)
      value.to_s
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2')
           .gsub(/([a-z\d])([A-Z])/, '\\1_\\2')
           .tr("-", "_")
           .downcase
    end

    def pluralize(word)
      return "#{word[0...-1]}ies" if word.end_with?("y") && word[-2] && !word[-2].match?(/[aeiou]/i)
      return "#{word}es" if word.end_with?("s", "x", "z", "ch", "sh")

      "#{word}s"
    end

    def camelize(word)
      word.to_s.split("_").map(&:capitalize).join
    end
  end
end
