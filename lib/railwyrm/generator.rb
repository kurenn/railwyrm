# frozen_string_literal: true

require "fileutils"

module Railwyrm
  class Generator
    RESPONSIVE_MAIN_CLASSES = "w-full min-h-screen flex justify-center".freeze
    TARGET_RUBY_VERSION = "3.4.0".freeze

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

      ui.info("Generating with Rails #{rails_version}") if rails_version

      ui.step("Bootstrapping base Rails app") do
        shell.run!(
          *blueprint.rails_new_command(configuration, rails_version: rails_version),
          chdir: configuration.workspace
        )
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
      ruby_line = %(ruby "~> #{target_ruby_version}")

      updated = if gemfile.match?(ruby_line_pattern)
                  gemfile.sub(ruby_line_pattern, ruby_line)
                else
                  "#{gemfile.rstrip}\n\n#{ruby_line}\n"
                end

      File.write(gemfile_path, updated) unless updated == gemfile
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

    def ensure_bullet_development_configuration!
      if configuration.dry_run
        ui.info("Dry run enabled: Bullet development config skipped.")
        return
      end

      patcher.ensure_bullet_development_configuration!
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

      patcher.ensure_ci_workflow_file!
    end

    def enable_optional_devise_modules!(module_names)
      ensure_devise_user!("Optional Devise modules require generating a Devise user model.")
      patcher.enable_optional_devise_modules!(module_names)
    end

    def enable_magic_link_authentication!
      ensure_devise_user!("Devise magic link requires generating a Devise user model.")
      patcher.enable_magic_link_authentication!
    end

    def enable_passkeys_authentication!
      ensure_devise_user!("Devise passkeys requires generating a Devise user model.")
      patcher.enable_passkeys_authentication!
    end

    # A dry run reports what it would do rather than refusing, so this stays
    # behind the dry-run check the way it always was.
    def ensure_devise_user!(message)
      return if configuration.dry_run || configuration.install_devise_user?

      raise InvalidConfiguration, message
    end

    def patcher
      @patcher ||= AppPatcher.new(
        app_path: configuration.app_path,
        ui: ui,
        shell: shell,
        dry_run: configuration.dry_run,
        devise_user_model: configuration.devise_user_model,
        display_name: configuration.name
      )
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

    def target_ruby_version
      TARGET_RUBY_VERSION
    end

    def rails_version
      @rails_version ||= configuration.rails_version || blueprint.default_rails_version
    end

  end
end
