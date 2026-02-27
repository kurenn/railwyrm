# frozen_string_literal: true

require "fileutils"

module Railwyrm
  class Generator
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

      ui.step("Normalize application layout main container") do
        normalize_application_main_layout!
      end

      ui.step("Apply Devise sign-in layout") do
        apply_sign_in_layout_template!
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
      additions = blueprint.gem_entries.each_with_object([]) do |entry, snippets|
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

    def apply_sign_in_layout_template!
      if configuration.dry_run
        ui.info("Dry run enabled: sign-in template copy skipped.")
        return
      end

      source = File.join(
        File.expand_path("..", __dir__),
        "railwyrm",
        "templates",
        "devise",
        "sign_in",
        configuration.sign_in_layout,
        "sessions",
        "new.html.erb"
      )

      unless File.exist?(source)
        raise InvalidConfiguration, "Sign-in template not found for '#{configuration.sign_in_layout}'"
      end

      destination = File.join(configuration.app_path, "app/views/devise/sessions/new.html.erb")
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
    end

    def normalize_application_main_layout!
      if configuration.dry_run
        ui.info("Dry run enabled: application layout update skipped.")
        return
      end

      layout_path = File.join(configuration.app_path, "app/views/layouts/application.html.erb")
      return unless File.exist?(layout_path)

      layout = File.read(layout_path)
      match = layout.match(/<main\s+class="([^"]*)">/)
      return unless match

      classes = match[1].split(/\s+/)
      classes.reject! { |klass| klass.start_with?("mt-") }
      classes << "flex" unless classes.include?("flex")
      classes << "justify-center" unless classes.include?("justify-center")

      updated = layout.sub(/<main\s+class="[^"]*">/, %(<main class="#{classes.join(' ')}">))
      File.write(layout_path, updated)
    end
  end
end
