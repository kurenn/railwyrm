# frozen_string_literal: true

require "fileutils"

module Railwyrm
  class FeatureInstaller
    OPTIONAL_DEVISE_MODULES = %w[confirmable lockable timeoutable trackable].freeze
    PASSKEYS_SUPPORT_NOTE = "Passkey registration could not start. Please try again on a supported browser.".freeze

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

      if features.include?("ci")
        ui.step("Install GitHub Actions CI workflow") do
          enable_ci_workflow!
        end
      end

      if features.include?("quality")
        ui.step("Configure development quality tooling") do
          enable_quality_tooling!
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

      if features.include?("quality")
        entries.concat(
          [
            {
              marker: 'gem "brakeman"',
              snippet: 'gem "brakeman", require: false'
            },
            {
              marker: 'gem "rubocop"',
              snippet: 'gem "rubocop", require: false'
            },
            {
              marker: 'gem "rubocop-rails"',
              snippet: 'gem "rubocop-rails", require: false'
            },
            {
              marker: 'gem "bullet"',
              snippet: 'gem "bullet"'
            }
          ]
        )
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
      resource_key = pluralize(underscore(devise_user_model))
      ensure_passkeys_devise_routes!(resource_key)
      ensure_model_includes_passkey_authenticatable!
      ensure_passkeys_controller!
      ensure_passkeys_view_template!
      ensure_webauthn_javascript_include!
      ensure_webauthn_initializer_defaults!
      ensure_webauthn_env_example_defaults!
      ensure_passkey_sign_in_button!
      ensure_passkey_enrollment_redirect!
      shell.run!("bin/rails", "db:migrate", chdir: app_path)
    end

    def enable_ci_workflow!
      if dry_run
        ui.info("Dry run enabled: CI workflow setup skipped.")
        return
      end

      ensure_ci_workflow_file!
    end

    def enable_quality_tooling!
      if dry_run
        ui.info("Dry run enabled: quality tooling setup skipped.")
        return
      end

      ensure_bullet_development_configuration!
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

    def ensure_passkeys_devise_routes!(resource_key)
      ensure_devise_controller_mapping!(resource_key, "passkeys", "users/passkeys")
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

    def ensure_passkeys_view_template!
      source = File.join(
        template_root,
        "devise",
        "passkeys",
        "new.html.erb"
      )
      raise InvalidConfiguration, "Passkeys view template missing: #{source}" unless File.exist?(source)

      destination = File.join(app_path, "app/views/devise/passkeys/new.html.erb")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def ensure_passkeys_controller!
      source = File.join(
        template_root,
        "devise",
        "passkeys",
        "users_controller.rb"
      )
      raise InvalidConfiguration, "Passkeys controller template missing: #{source}" unless File.exist?(source)

      destination = File.join(app_path, "app/controllers/users/passkeys_controller.rb")
      FileUtils.mkdir_p(File.dirname(destination))
      content = File.read(source).gsub("__PASSKEYS_SUPPORT_NOTE__", PASSKEYS_SUPPORT_NOTE)
      File.write(destination, content)
    end

    def ensure_ci_workflow_file!
      source = File.join(template_root, "ci", "github_actions_ci.yml")
      raise InvalidConfiguration, "CI workflow template missing: #{source}" unless File.exist?(source)

      destination = File.join(app_path, ".github/workflows/ci.yml")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def ensure_bullet_development_configuration!
      development_path = File.join(app_path, "config/environments/development.rb")
      return unless File.exist?(development_path)

      content = File.read(development_path)
      return if content.include?("Bullet.enable = true")

      bullet_block = <<~RUBY

        config.after_initialize do
          Bullet.enable = true
          Bullet.alert = true
          Bullet.bullet_logger = true
          Bullet.rails_logger = true
        end
      RUBY

      updated = content.sub(/\nend\s*\z/, "\n#{indent_block(bullet_block.rstrip, 2)}\nend\n")
      raise InvalidConfiguration, "Unable to inject Bullet config into #{development_path}" if updated == content

      File.write(development_path, updated)
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

    def ensure_webauthn_initializer_defaults!
      initializer_path = File.join(app_path, "config/initializers/webauthn.rb")
      return unless File.exist?(initializer_path)

      content = File.read(initializer_path)
      updated = content

      app_label = app_display_name
      rp_name_line = %(  config.rp_name = ENV.fetch("WEBAUTHN_RP_NAME", "#{app_label}"))
      rp_id_line = %(  config.rp_id = ENV.fetch("WEBAUTHN_RP_ID", "localhost"))
      allowed_origins_line = '  config.allowed_origins = ENV.fetch("WEBAUTHN_ALLOWED_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000").split(",").map(&:strip).reject(&:empty?)'

      if updated.match?(/^\s*#?\s*config\.rp_name\s*=.*$/)
        updated = updated.gsub(/^\s*#?\s*config\.rp_name\s*=.*$/, rp_name_line)
      elsif !updated.include?(rp_name_line)
        updated = updated.sub(/WebAuthn\.configure do \|config\|\n/, "WebAuthn.configure do |config|\n#{rp_name_line}\n")
      end

      if updated.match?(/^\s*#?\s*config\.rp_id\s*=.*$/)
        updated = updated.gsub(/^\s*#?\s*config\.rp_id\s*=.*$/, rp_id_line)
      elsif !updated.include?(rp_id_line)
        updated = updated.sub("#{rp_name_line}\n", "#{rp_name_line}\n#{rp_id_line}\n")
      end

      if updated.match?(/^\s*#?\s*config\.allowed_origins\s*=.*$/)
        updated = updated.gsub(/^\s*#?\s*config\.allowed_origins\s*=.*$/, allowed_origins_line)
      elsif !updated.include?(allowed_origins_line)
        updated = updated.sub("#{rp_id_line}\n", "#{rp_id_line}\n#{allowed_origins_line}\n")
      end

      File.write(initializer_path, updated) unless updated == content
    end

    def ensure_webauthn_env_example_defaults!
      env_example_path = File.join(app_path, ".env.example")
      content = File.exist?(env_example_path) ? File.read(env_example_path) : ""
      updated = content

      env_lines = {
        "WEBAUTHN_RP_NAME" => app_display_name,
        "WEBAUTHN_RP_ID" => "localhost",
        "WEBAUTHN_ALLOWED_ORIGINS" => "http://localhost:3000,http://127.0.0.1:3000"
      }

      env_lines.each do |key, value|
        line = "#{key}=#{value}"
        pattern = /^\s*#{Regexp.escape(key)}=.*$/
        if updated.match?(pattern)
          updated = updated.gsub(pattern, line)
        elsif updated.strip.empty?
          updated = "#{line}\n"
        else
          updated = "#{updated.rstrip}\n#{line}\n"
        end
      end

      File.write(env_example_path, updated) unless updated == content
    end

    def ensure_webauthn_javascript_include!
      layout_path = File.join(app_path, "app/views/layouts/application.html.erb")
      return unless File.exist?(layout_path)

      content = File.read(layout_path)
      module_include_line = '<%= javascript_include_tag "devise/webauthn", type: "module" %>'
      updated = content

      if updated.include?(module_include_line)
        return
      elsif updated.match?(/<%=\s*javascript_include_tag\s+["']devise\/webauthn["']\s*%>/)
        updated = updated.gsub(/<%=\s*javascript_include_tag\s+["']devise\/webauthn["']\s*%>/, module_include_line)
      elsif updated.include?("<%= stylesheet_link_tag")
        updated = updated.sub("<%= stylesheet_link_tag", "#{module_include_line}\n    <%= stylesheet_link_tag")
      elsif updated.include?("</head>")
        updated = updated.sub("</head>", "    #{module_include_line}\n  </head>")
      end

      File.write(layout_path, updated) unless updated == content
    end

    def ensure_passkey_sign_in_button!
      session_view_path = File.join(app_path, "app/views/devise/sessions/new.html.erb")
      return unless File.exist?(session_view_path)

      content = File.read(session_view_path)
      return if content.include?("login_with_passkey_button")

      passkey_button_block = <<~ERB

        <% if respond_to?(:login_with_passkey_button) %>
          <div class="mt-4 text-center text-sm text-tertiary">
            <%= login_with_passkey_button("Sign in with passkey", session_path: session_path(resource_name)) %>
          </div>
        <% end %>
      ERB

      updated = if content.include?("<% if devise_mapping.registerable? %>")
                  content.sub("<% if devise_mapping.registerable? %>", "#{passkey_button_block}\n<% if devise_mapping.registerable? %>")
                else
                  "#{content.rstrip}\n#{passkey_button_block}"
                end
      File.write(session_view_path, updated) unless updated == content
    end

    def ensure_passkey_enrollment_redirect!
      controller_path = File.join(app_path, "app/controllers/application_controller.rb")
      return unless File.exist?(controller_path)

      content = File.read(controller_path)
      return if content.include?("def after_sign_in_path_for")

      snippet = <<~RUBY

          protected

          def after_sign_in_path_for(resource_or_scope)
            resource = resource_or_scope.is_a?(Symbol) ? nil : resource_or_scope

            if resource&.respond_to?(:passkeys) && resource.passkeys.none?
              scope = Devise::Mapping.find_scope!(resource)
              helper = :"new_\#{scope}_passkey_path"
              return public_send(helper) if respond_to?(helper)
            end

            super
          end
      RUBY

      updated = content.sub(/\nend\s*\z/, "#{snippet}\nend\n")
      raise InvalidConfiguration, "Unable to inject passkey redirect into #{controller_path}" if updated == content

      File.write(controller_path, updated)
    end

    def ensure_devise_controller_mapping!(resource_key, controller_name, controller_path)
      routes_path = File.join(app_path, "config/routes.rb")
      raise InvalidConfiguration, "Routes file not found: #{routes_path}" unless File.exist?(routes_path)

      routes_content = File.read(routes_path)
      controller_fragment = %(#{controller_name}: "#{controller_path}")
      return if routes_content.include?(controller_fragment)

      pattern = /^(\s*devise_for\s+:#{Regexp.escape(resource_key)})([^\n]*)$/
      match = routes_content.match(pattern)
      raise InvalidConfiguration, "Could not find devise_for :#{resource_key} route in #{routes_path}" unless match

      full_line = match[0]
      suffix = match[2]
      updated_line = if suffix.include?("controllers:")
                       full_line.sub(/controllers:\s*\{([^}]*)\}/) do
                         inner = Regexp.last_match(1).strip
                         entries = inner.empty? ? controller_fragment : "#{inner}, #{controller_fragment}"
                         "controllers: { #{entries} }"
                       end
                     else
                       "#{match[1]}#{suffix}, controllers: { #{controller_fragment} }"
                     end

      updated = routes_content.sub(full_line, updated_line)
      File.write(routes_path, updated)
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

    def app_display_name
      File.basename(app_path).tr("-", "_").split("_").map(&:capitalize).join(" ")
    end

    def indent_block(value, spaces)
      indent = " " * spaces
      value.lines.map { |line| line.strip.empty? ? line : "#{indent}#{line}" }.join
    end
  end
end
