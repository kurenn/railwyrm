# frozen_string_literal: true

require "fileutils"

module Railwyrm
  class Generator
    RESPONSIVE_MAIN_CLASSES = "w-full min-h-screen flex justify-center".freeze
    PASSKEYS_SUPPORT_NOTE = "Passkey registration could not start. Please try again on a supported browser.".freeze
    TARGET_RUBY_VERSION = "3.3.0".freeze

    def initialize(configuration, ui:, shell: nil, blueprint: RailsBlueprint.new)
      @configuration = configuration
      @ui = ui
      @blueprint = blueprint
      @shell = shell || Shell.new(ui: ui, dry_run: configuration.dry_run, verbose: configuration.verbose)
    end

    def run!
      ensure_workspace!
      ensure_destination_available!

      ui.headline("Forging #{configuration.name} in #{configuration.workspace}")

      ui.step("Bootstrapping base Rails app") do
        shell.run!(*blueprint.rails_new_command(configuration), chdir: configuration.workspace)
      end

      ui.step("Checking Rails and Ruby compatibility") do
        ensure_generated_rails_version_compatible!
      end

      ui.step("Pinning generated Ruby version") do
        ensure_generated_ruby_version!
      end

      ui.step("Injecting default gems") do
        inject_default_gems!
      end

      ui.step("Installing bundle") do
        shell.run!("bundle", "install", chdir: configuration.app_path)
      end

      blueprint.post_bundle_steps(configuration).each do |label, command|
        ui.step(label) do
          shell.run!(*command, chdir: configuration.app_path)
        end
      end

      if configuration.devise_magic_link?
        ui.step("Install magic-link authentication") do
          enable_magic_link_authentication!
        end
      end

      if configuration.devise_passkeys?
        ui.step("Install passkeys authentication") do
          enable_passkeys_authentication!
        end
      end

      optional_devise_modules = selected_optional_devise_modules
      unless optional_devise_modules.empty?
        ui.step("Enable Devise modules: #{optional_devise_modules.join(', ')}") do
          enable_optional_devise_modules!(optional_devise_modules)
        end
      end

      ui.step("Normalize application layout main container") do
        normalize_application_main_layout!
      end

      ui.step("Apply Devise auth view templates") do
        apply_devise_view_templates!
      end

      ui.step("Configure development quality tools") do
        ensure_bullet_development_configuration!
      end

      ui.step("Normalize generated lint defaults") do
        ensure_devise_initializer_lint_defaults!
      end

      ui.step("Configure GitHub Actions CI workflow") do
        ensure_ci_workflow!
      end

      ui.step("Record installed feature state") do
        persist_feature_state!
      end

      ui.success("Rails realm forged at #{configuration.app_path}")
      configuration.app_path
    end

    private

    attr_reader :configuration, :ui, :blueprint, :shell

    def ensure_workspace!
      return if configuration.dry_run

      FileUtils.mkdir_p(configuration.workspace)
    end

    def ensure_destination_available!
      return if configuration.dry_run

      raise InvalidConfiguration, "Destination already exists: #{configuration.app_path}" if Dir.exist?(configuration.app_path)
    end

    def inject_default_gems!
      if configuration.dry_run
        ui.info("Dry run enabled: Gemfile update skipped.")
        return
      end

      gemfile_path = File.join(configuration.app_path, "Gemfile")
      raise InvalidConfiguration, "Gemfile not found at #{gemfile_path}" unless File.exist?(gemfile_path)

      gemfile = File.read(gemfile_path)
      entries = blueprint.gem_entries + blueprint.optional_gem_entries(configuration)
      additions = entries.each_with_object([]) do |entry, snippets|
        snippets << entry[:snippet] unless gemfile.include?(entry[:marker])
      end

      if additions.empty?
        ui.info("All default gems already exist in Gemfile.")
        return
      end

      updated = "#{gemfile.rstrip}\n\n#{additions.join("\n\n")}\n"
      File.write(gemfile_path, updated)
      ui.success("Gemfile updated with Rails starter stack.")
    end

    def ensure_generated_rails_version_compatible!
      if configuration.dry_run
        ui.info("Dry run enabled: Rails compatibility check skipped.")
        return
      end

      gemfile_path = File.join(configuration.app_path, "Gemfile")
      raise InvalidConfiguration, "Gemfile not found at #{gemfile_path}" unless File.exist?(gemfile_path)

      required_version = blueprint.compatible_rails_requirement(target_ruby_version)
      return if required_version.nil?

      gemfile = File.read(gemfile_path)
      rails_line_pattern = /^(gem ["']rails["'],\s*["'])~> 8\.1\.[^"']+(["'])$/
      return unless gemfile.match?(rails_line_pattern)

      updated = gemfile.sub(rails_line_pattern, "\\1#{required_version}\\2")
      return if updated == gemfile

      File.write(gemfile_path, updated)
      ensure_generated_load_defaults_version!(required_version)
      ui.info("Generated app targets Ruby #{target_ruby_version}; pinning Rails to #{required_version}.")
    end

    def ensure_generated_ruby_version!
      if configuration.dry_run
        ui.info("Dry run enabled: Ruby version pin skipped.")
        return
      end

      ruby_version_path = File.join(configuration.app_path, ".ruby-version")
      File.write(ruby_version_path, "#{target_ruby_version}\n")

      gemfile_path = File.join(configuration.app_path, "Gemfile")
      raise InvalidConfiguration, "Gemfile not found at #{gemfile_path}" unless File.exist?(gemfile_path)

      gemfile = File.read(gemfile_path)
      ruby_line_pattern = /^ruby ["'][^"']+["']$/
      ruby_line = %(ruby "#{target_ruby_version}")

      updated = if gemfile.match?(ruby_line_pattern)
                  gemfile.sub(ruby_line_pattern, ruby_line)
                else
                  "#{gemfile.rstrip}\n\n#{ruby_line}\n"
                end

      File.write(gemfile_path, updated) unless updated == gemfile
    end

    def ensure_generated_load_defaults_version!(rails_requirement)
      application_path = File.join(configuration.app_path, "config/application.rb")
      return unless File.exist?(application_path)

      load_defaults_version = rails_requirement[/\d+\.\d+/]
      return if load_defaults_version.nil?

      application = File.read(application_path)
      updated = application.gsub(/config\.load_defaults\s+\d+\.\d+/, "config.load_defaults #{load_defaults_version}")
      File.write(application_path, updated) unless updated == application
    end

    def apply_devise_view_templates!
      if configuration.dry_run
        ui.info("Dry run enabled: Devise template copy skipped.")
        return
      end

      source_root = File.join(
        File.expand_path("..", __dir__),
        "railwyrm",
        "templates",
        "devise",
        "sign_in",
        configuration.sign_in_layout
      )

      unless Dir.exist?(source_root)
        raise InvalidConfiguration, "Devise templates not found for '#{configuration.sign_in_layout}'"
      end

      destination_root = File.join(configuration.app_path, "app/views/devise")

      Dir.glob(File.join(source_root, "**", "*.erb")).sort.each do |source|
        relative_path = source.delete_prefix("#{source_root}/")
        destination = File.join(destination_root, relative_path)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source, destination)
      end
    end

    def enable_optional_devise_modules!(module_names)
      if configuration.dry_run
        ui.info("Dry run enabled: optional Devise module setup skipped.")
        return
      end

      unless configuration.install_devise_user?
        raise InvalidConfiguration, "Optional Devise modules require generating a Devise user model."
      end

      model_relative_path = "app/models/#{underscore(configuration.devise_user_model)}.rb"
      model_path = File.join(configuration.app_path, model_relative_path)
      raise InvalidConfiguration, "Devise model file not found: #{model_relative_path}" unless File.exist?(model_path)

      model_content = File.read(model_path)
      updated_model = inject_devise_modules_into_model(model_content, module_names, model_relative_path)
      File.write(model_path, updated_model) unless updated_model == model_content

      migration_created = false
      migration_created ||= ensure_confirmable_migration! if module_names.include?("confirmable")
      migration_created ||= ensure_lockable_migration! if module_names.include?("lockable")
      migration_created ||= ensure_trackable_migration! if module_names.include?("trackable")
      shell.run!("bin/rails", "db:migrate", chdir: configuration.app_path) if migration_created
    end

    def enable_magic_link_authentication!
      if configuration.dry_run
        ui.info("Dry run enabled: magic-link setup skipped.")
        return
      end

      unless configuration.install_devise_user?
        raise InvalidConfiguration, "Devise magic link requires generating a Devise user model."
      end

      shell.run!("bin/rails", "generate", "devise:passwordless:install", "--force", chdir: configuration.app_path)

      resource_key = pluralize(underscore(configuration.devise_user_model))
      ensure_model_includes_magic_link_authenticatable!
      ensure_passwordless_routes!(resource_key)
      ensure_passwordless_session_template!
      ensure_passwordless_mailer_templates!
      ensure_devise_paranoid_mode!
      ensure_development_mail_file_delivery!
    end

    def enable_passkeys_authentication!
      if configuration.dry_run
        ui.info("Dry run enabled: passkeys setup skipped.")
        return
      end

      unless configuration.install_devise_user?
        raise InvalidConfiguration, "Devise passkeys requires generating a Devise user model."
      end

      shell.run!("bin/rails", "generate", "devise:webauthn:install", "--force", chdir: configuration.app_path)
      resource_key = pluralize(underscore(configuration.devise_user_model))
      ensure_passkeys_devise_routes!(resource_key)
      ensure_model_includes_passkey_authenticatable!
      ensure_passkeys_controller!
      ensure_passkeys_view_template!
      ensure_webauthn_javascript_include!
      ensure_webauthn_initializer_defaults!
      ensure_webauthn_env_example_defaults!
      ensure_passkey_sign_in_button!
      ensure_passkey_enrollment_redirect!
      shell.run!("bin/rails", "db:migrate", chdir: configuration.app_path)
    end

    def normalize_application_main_layout!
      if configuration.dry_run
        ui.info("Dry run enabled: application layout update skipped.")
        return
      end

      layout_path = File.join(configuration.app_path, "app/views/layouts/application.html.erb")
      return unless File.exist?(layout_path)

      layout = File.read(layout_path)
      updated = if layout.match?(/<main\s+class="[^"]*">/)
                  layout.sub(/<main\s+class="[^"]*">/, %(<main class="#{RESPONSIVE_MAIN_CLASSES}">))
                elsif layout.match?(/<main>/)
                  layout.sub(/<main>/, %(<main class="#{RESPONSIVE_MAIN_CLASSES}">))
                else
                  layout
                end

      File.write(layout_path, updated) unless updated == layout
    end

    def ensure_model_includes_magic_link_authenticatable!
      model_relative_path = "app/models/#{underscore(configuration.devise_user_model)}.rb"
      model_path = File.join(configuration.app_path, model_relative_path)
      raise InvalidConfiguration, "Devise model file not found: #{model_relative_path}" unless File.exist?(model_path)

      model_content = File.read(model_path)
      updated = inject_devise_modules_into_model(model_content, ["magic_link_authenticatable"], model_relative_path)
      File.write(model_path, updated)
    end

    def ensure_model_includes_passkey_authenticatable!
      model_relative_path = "app/models/#{underscore(configuration.devise_user_model)}.rb"
      model_path = File.join(configuration.app_path, model_relative_path)
      raise InvalidConfiguration, "Devise model file not found: #{model_relative_path}" unless File.exist?(model_path)

      model_content = File.read(model_path)
      updated = inject_devise_modules_into_model(model_content, ["passkey_authenticatable"], model_relative_path)
      File.write(model_path, updated)
    end

    def ensure_passkeys_devise_routes!(resource_key)
      ensure_devise_controller_mapping!(resource_key, "passkeys", "users/passkeys")
    end

    def ensure_passwordless_routes!(resource_key)
      routes_path = File.join(configuration.app_path, "config/routes.rb")
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
        File.expand_path("..", __dir__),
        "railwyrm",
        "templates",
        "devise",
        "passwordless",
        "sessions",
        "new.html.erb"
      )
      raise InvalidConfiguration, "Passwordless session template missing: #{source}" unless File.exist?(source)

      destination = File.join(configuration.app_path, "app/views/devise/passwordless/sessions/new.html.erb")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def ensure_passkeys_view_template!
      source = File.join(
        File.expand_path("..", __dir__),
        "railwyrm",
        "templates",
        "devise",
        "passkeys",
        "new.html.erb"
      )
      raise InvalidConfiguration, "Passkeys view template missing: #{source}" unless File.exist?(source)

      destination = File.join(configuration.app_path, "app/views/devise/passkeys/new.html.erb")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def ensure_passkeys_controller!
      source = File.join(
        File.expand_path("..", __dir__),
        "railwyrm",
        "templates",
        "devise",
        "passkeys",
        "users_controller.rb"
      )
      raise InvalidConfiguration, "Passkeys controller template missing: #{source}" unless File.exist?(source)

      destination = File.join(configuration.app_path, "app/controllers/users/passkeys_controller.rb")
      FileUtils.mkdir_p(File.dirname(destination))
      content = File.read(source).gsub("__PASSKEYS_SUPPORT_NOTE__", PASSKEYS_SUPPORT_NOTE)
      File.write(destination, content)
    end

    def ensure_passwordless_mailer_templates!
      source = File.join(
        File.expand_path("..", __dir__),
        "railwyrm",
        "templates",
        "devise",
        "passwordless",
        "mailer",
        "magic_link.text.erb"
      )
      raise InvalidConfiguration, "Passwordless mailer template missing: #{source}" unless File.exist?(source)

      destination = File.join(configuration.app_path, "app/views/devise/mailer/magic_link.text.erb")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def ensure_devise_paranoid_mode!
      initializer_path = File.join(configuration.app_path, "config/initializers/devise.rb")
      return unless File.exist?(initializer_path)

      content = File.read(initializer_path)
      updated = if content.match?(/^\s*#?\s*config\.paranoid\s*=.*$/)
                  content.gsub(/^\s*#?\s*config\.paranoid\s*=.*$/, "  config.paranoid = true")
                else
                  content.sub(/Devise\.setup do \|config\|\n/, "Devise.setup do |config|\n  config.paranoid = true\n")
                end
      File.write(initializer_path, updated) unless updated == content
    end

    def ensure_webauthn_initializer_defaults!
      initializer_path = File.join(configuration.app_path, "config/initializers/webauthn.rb")
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
      env_example_path = File.join(configuration.app_path, ".env.example")
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
      layout_path = File.join(configuration.app_path, "app/views/layouts/application.html.erb")
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
      session_view_path = File.join(configuration.app_path, "app/views/devise/sessions/new.html.erb")
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
      controller_path = File.join(configuration.app_path, "app/controllers/application_controller.rb")
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
      routes_path = File.join(configuration.app_path, "config/routes.rb")
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

    def ensure_development_mail_file_delivery!
      development_path = File.join(configuration.app_path, "config/environments/development.rb")
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

    def ensure_bullet_development_configuration!
      if configuration.dry_run
        ui.info("Dry run enabled: Bullet development config skipped.")
        return
      end

      development_path = File.join(configuration.app_path, "config/environments/development.rb")
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

    def ensure_devise_initializer_lint_defaults!
      if configuration.dry_run
        ui.info("Dry run enabled: Devise lint normalization skipped.")
        return
      end

      initializer_path = File.join(configuration.app_path, "config/initializers/devise.rb")
      return unless File.exist?(initializer_path)

      content = File.read(initializer_path)
      updated = content.dup

      updated.gsub!(
        "config.mailer_sender = 'please-change-me-at-config-initializers-devise@example.com'",
        'config.mailer_sender = "please-change-me-at-config-initializers-devise@example.com"'
      )
      updated.gsub!("require 'devise/orm/active_record'", 'require "devise/orm/active_record"')
      updated.gsub!("config.case_insensitive_keys = [:email]", "config.case_insensitive_keys = [ :email ]")
      updated.gsub!("config.strip_whitespace_keys = [:email]", "config.strip_whitespace_keys = [ :email ]")
      updated.gsub!("config.skip_session_storage = [:http_auth]", "config.skip_session_storage = [ :http_auth ]")

      File.write(initializer_path, updated) unless updated == content
    end

    def ensure_ci_workflow!
      if configuration.dry_run
        ui.info("Dry run enabled: CI workflow setup skipped.")
        return
      end

      source = File.join(
        File.expand_path("..", __dir__),
        "railwyrm",
        "templates",
        "ci",
        "github_actions_ci.yml"
      )
      raise InvalidConfiguration, "CI workflow template missing: #{source}" unless File.exist?(source)

      destination = File.join(configuration.app_path, ".github/workflows/ci.yml")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def selected_optional_devise_modules
      modules = []
      modules << "confirmable" if configuration.devise_confirmable?
      modules << "lockable" if configuration.devise_lockable?
      modules << "timeoutable" if configuration.devise_timeoutable?
      modules << "trackable" if configuration.devise_trackable?
      modules
    end

    def selected_feature_registry_names
      selected = %w[ci quality] + selected_optional_devise_modules
      selected << "magic_link" if configuration.devise_magic_link?
      selected << "passkeys" if configuration.devise_passkeys?
      selected.uniq
    end

    def persist_feature_state!
      feature_state = FeatureState.new(app_path: configuration.app_path, ui: ui, dry_run: configuration.dry_run)
      feature_state.replace!(selected_feature_registry_names)
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
      migration_dir = File.join(configuration.app_path, "db/migrate")
      FileUtils.mkdir_p(migration_dir)

      table_name = pluralize(underscore(configuration.devise_user_model))
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
      migration_dir = File.join(configuration.app_path, "db/migrate")
      FileUtils.mkdir_p(migration_dir)

      table_name = pluralize(underscore(configuration.devise_user_model))
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
      migration_dir = File.join(configuration.app_path, "db/migrate")
      FileUtils.mkdir_p(migration_dir)

      table_name = pluralize(underscore(configuration.devise_user_model))
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
      Dir.glob(File.join(configuration.app_path, "db/migrate/*.rb")).sort.each do |path|
        match = File.read(path).match(/ActiveRecord::Migration\[(\d+\.\d+)\]/)
        return match[1] if match
      end

      "8.0"
    end

    def underscore(value)
      value.to_s
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
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
      configuration.name.to_s.tr("-", "_").split("_").map(&:capitalize).join(" ")
    end

    def current_ruby_version
      RUBY_VERSION
    end

    def target_ruby_version
      TARGET_RUBY_VERSION
    end

    def indent_block(content, spaces)
      prefix = " " * spaces
      content.lines.map { |line| line.strip.empty? ? line : "#{prefix}#{line}" }.join
    end
  end
end
