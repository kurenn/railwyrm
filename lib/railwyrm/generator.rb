# frozen_string_literal: true

require "fileutils"

module Railwyrm
  class Generator
    RESPONSIVE_MAIN_CLASSES = "w-full min-h-screen flex justify-center".freeze

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

      if configuration.devise_two_factor?
        ui.step("Install Devise two-factor authentication") do
          enable_devise_two_factor!
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
      shell.run!("bin/rails", "db:migrate", chdir: configuration.app_path) if migration_created
    end

    def enable_devise_two_factor!
      if configuration.dry_run
        ui.info("Dry run enabled: Devise two-factor setup skipped.")
        return
      end

      unless configuration.install_devise_user?
        raise InvalidConfiguration, "Devise two-factor requires generating a Devise user model."
      end

      shell.run!(
        "bin/rails",
        "generate",
        "devise_two_factor",
        configuration.devise_user_model,
        "--force",
        chdir: configuration.app_path
      )
      ensure_application_controller_allows_otp_attempt!
      ensure_filter_parameter_logging_masks_otp_attempt!
      ensure_devise_initializer_resets_session_after_password_reset!
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

    def selected_optional_devise_modules
      modules = []
      modules << "confirmable" if configuration.devise_confirmable?
      modules << "lockable" if configuration.devise_lockable?
      modules << "timeoutable" if configuration.devise_timeoutable?
      modules
    end

    def ensure_application_controller_allows_otp_attempt!
      controller_path = File.join(configuration.app_path, "app/controllers/application_controller.rb")
      return unless File.exist?(controller_path)

      before_action_line = "  before_action :configure_permitted_parameters, if: :devise_controller?"
      permit_line = "    devise_parameter_sanitizer.permit(:sign_in, keys: [:otp_attempt])"
      content = File.read(controller_path)

      unless content.include?(before_action_line)
        content = content.sub(
          /(class ApplicationController < [^\n]+\n)/,
          "\\1#{before_action_line}\n"
        )
      end

      unless content.include?(permit_line.strip)
        content = if content.match?(/^\s*def configure_permitted_parameters\b/)
                    content.sub(/(^\s*def configure_permitted_parameters\b.*?\n)(.*?)(^\s*end\b)/m) do
                      method_header = Regexp.last_match(1)
                      method_body = Regexp.last_match(2)
                      method_end = Regexp.last_match(3)
                      "#{method_header}#{method_body}#{permit_line}\n#{method_end}"
                    end
                  else
                    content.sub(
                      /\nend\s*\z/,
                      "\n\n  protected\n\n  def configure_permitted_parameters\n#{permit_line}\n  end\nend\n"
                    )
                  end
      end

      File.write(controller_path, content)
    end

    def ensure_filter_parameter_logging_masks_otp_attempt!
      filter_path = File.join(configuration.app_path, "config/initializers/filter_parameter_logging.rb")
      return unless File.exist?(filter_path)

      content = File.read(filter_path)
      return if content.include?(":otp_attempt")

      updated = "#{content.rstrip}\n\nRails.application.config.filter_parameters += [:otp_attempt]\n"
      File.write(filter_path, updated)
    end

    def ensure_devise_initializer_resets_session_after_password_reset!
      initializer_path = File.join(configuration.app_path, "config/initializers/devise.rb")
      return unless File.exist?(initializer_path)

      content = File.read(initializer_path)
      return if content.include?("config.sign_in_after_reset_password = false")

      updated = content.gsub(
        /^\s*#?\s*config\.sign_in_after_reset_password\s*=.*$/,
        "  config.sign_in_after_reset_password = false"
      )

      if updated == content
        updated = content.sub(
          /Devise\.setup do \|config\|\n/,
          "Devise.setup do |config|\n  config.sign_in_after_reset_password = false\n"
        )
      end

      File.write(initializer_path, updated)
    end

    def inject_devise_modules_into_model(model_content, module_names, model_relative_path)
      missing = module_names.reject { |mod| model_content.include?(":#{mod}") }
      return model_content if missing.empty?

      updated = model_content.sub(/^\s*devise\s+.+$/) do |line|
        indentation = line[/^\s*/]
        modules = line.sub(/^\s*devise\s+/, "")
        missing_prefix = missing.map { |mod| ":#{mod}" }.join(", ")
        "#{indentation}devise #{missing_prefix}, #{modules}"
      end

      if updated == model_content
        raise InvalidConfiguration, "Could not find Devise module declaration in #{model_relative_path}"
      end

      updated
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
  end
end
