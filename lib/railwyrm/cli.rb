# frozen_string_literal: true

require "open3"

module Railwyrm
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    SIGN_IN_LAYOUT_MENU_CHOICES = [
      { label: "Simple Minimal (centered form)", value: "simple_minimal" },
      { label: "Card Combined (recommended)", value: "card_combined" },
      { label: "Split Mockup Quote (marketing side panel)", value: "split_mockup_quote" }
    ].freeze

    class Recipes < Thor
      package_name "railwyrm recipes"

      desc "list", "List available recipes"
      def list
        ui = UI::Console.new(verbose: false)
        recipes = discover_recipe_paths.sort.filter_map do |recipe_path|
          begin
            recipe = Recipe.load(recipe_path)
            {
              id: recipe.id,
              name: recipe.metadata["name"],
              version: recipe.version,
              status: recipe.metadata["status"],
              path: recipe.path
            }
          rescue StandardError => e
            ui.warn("Skipping invalid recipe at #{recipe_path}: #{e.message}")
            nil
          end
        end

        if recipes.empty?
          ui.warn("No recipes found.")
          return
        end

        ui.headline("Available recipes")
        recipes.each do |recipe|
          ui.info("#{recipe[:id]}@#{recipe[:version]} [#{recipe[:status]}] - #{recipe[:name]}")
          ui.info("  #{recipe[:path]}")
        end
      end

      desc "profiles", "List shared UI profiles available to recipes"
      def profiles
        ui = UI::Console.new(verbose: false)
        catalog = ui_profile_catalog
        profiles = catalog.list

        if profiles.empty?
          ui.warn("No shared UI profiles found.")
          return
        end

        ui.headline("Shared UI profiles")
        profiles.each do |profile|
          missing_paths = catalog.missing_overlay_paths_for(profile)
          if missing_paths.empty?
            ui.info("#{profile} [ready]")
          else
            ui.warn("#{profile} [incomplete]")
            missing_paths.each { |path| ui.warn("  missing: #{path}") }
          end
        end
      end

      desc "show RECIPE", "Show recipe metadata, modules, commands, and quality gates"
      def show(recipe_ref)
        ui = UI::Console.new(verbose: false)
        recipe = load_recipe(recipe_ref)
        data = recipe.data

        ui.headline("#{recipe.id}@#{recipe.version}")
        ui.info("Name: #{data['name']}")
        ui.info("Status: #{data['status']}")
        ui.info("Path: #{recipe.path}")
        ui.info("Description: #{data['description']}")
        ui.info("UI profile: #{recipe.ui_profile}") if recipe.ui_profile

        modules = data.dig("inputs", "with_modules", "allowed")
        if modules.is_a?(Array) && !modules.empty?
          ui.info("Modules: #{modules.join(', ')}")
        end

        deploy_presets = recipe.deploy_preset_names
        unless deploy_presets.empty?
          ui.info("Deploy presets: #{deploy_presets.join(', ')}")
        end

        commands = recipe.scaffolding_commands
        ui.info("Scaffolding commands: #{commands.length}")
        commands.each_with_index { |command, index| ui.info("  #{index + 1}. #{command}") }

        gates = recipe.quality_gate_commands
        ui.info("Quality gates: #{gates.length}")
        gates.each_with_index { |command, index| ui.info("  #{index + 1}. #{command}") }
      rescue StandardError => e
        ui.error(e.message)
        exit(1)
      end

      desc "validate [RECIPE_PATH]", "Validate a recipe.yml file against Railwyrm schema v0"
      def validate(recipe_path = "recipe.yml")
        ui = UI::Console.new(verbose: false)
        path = resolve_recipe_path(recipe_path)
        result = RecipeSchema.new.validate_file(path)

        if result.valid?
          begin
            recipe = Recipe.load(path)
            profile_errors = recipe.ui_profile_validation_errors
            if profile_errors.empty?
              ui.success("Recipe is valid: #{path}")
              return
            end

            ui.error("Recipe validation failed: #{path}")
            profile_errors.each { |error| ui.warn(error) }
            exit(1)
          rescue StandardError => e
            ui.error("Recipe validation failed: #{path}")
            ui.warn(e.message)
            exit(1)
          end
        end

        ui.error("Recipe validation failed: #{path}")
        result.errors.each { |error| ui.warn(error) }
        exit(1)
      end

      desc "plan [RECIPE_PATH]", "Show deterministic execution plan for a recipe"
      option :workspace, aliases: "-w", type: :string, default: Dir.pwd, desc: "Target workspace"
      option :with, type: :array, default: [], desc: "Enable optional recipe modules"
      option :deploy, type: :string, desc: "Deploy preset to apply in plan/apply (e.g. render)"
      def plan(recipe_path = "recipe.yml")
        ui = UI::Console.new(verbose: false)
        recipe = load_recipe(recipe_path)
        executor = RecipeExecutor.new(
          recipe,
          workspace: options[:workspace],
          ui: ui,
          shell: Shell.new(ui: ui, dry_run: true, verbose: false),
          dry_run: true,
          selected_modules: normalized_modules_option(options[:with]),
          deploy_preset: options[:deploy]
        )

        ui.headline("Plan for #{recipe.id}@#{recipe.version}")
        ui.info("Recipe file: #{recipe.path}")
        ui.info("Workspace: #{File.expand_path(options[:workspace])}")
        selected = recipe.resolve_modules(normalized_modules_option(options[:with]))
        ui.info("Modules: #{selected.join(', ')}") unless selected.empty?
        ui.info("Deploy preset: #{options[:deploy]}") unless options[:deploy].to_s.strip.empty?
        executor.plan.each do |step|
          ui.info("#{step.index}. #{step.command}")
        end
      rescue StandardError => e
        ui.error(e.message)
        exit(1)
      end

      desc "apply [RECIPE_PATH]", "Apply a recipe deterministically in command order"
      option :workspace, aliases: "-w", type: :string, default: Dir.pwd, desc: "Target workspace"
      option :verbose, type: :boolean, default: false, desc: "Stream command output"
      option :dry_run, aliases: "--dry_run", type: :boolean, default: false,
                        desc: "Print commands without executing"
      option :with, type: :array, default: [], desc: "Enable optional recipe modules"
      option :deploy, type: :string, desc: "Deploy preset to apply (e.g. render)"
      def apply(recipe_path = "recipe.yml")
        ui = UI::Console.new(verbose: effective_verbose?)
        recipe = load_recipe(recipe_path)
        dry_run = effective_dry_run?
        shell = Shell.new(ui: ui, dry_run: dry_run, verbose: effective_verbose?)
        executor = RecipeExecutor.new(
          recipe,
          workspace: options[:workspace],
          ui: ui,
          shell: shell,
          dry_run: dry_run,
          selected_modules: normalized_modules_option(options[:with]),
          deploy_preset: options[:deploy]
        )
        executor.apply!
      rescue StandardError => e
        ui.error(e.message)
        exit(1)
      end

      private

      def load_recipe(recipe_path)
        Recipe.load(resolve_recipe_path(recipe_path))
      end

      def effective_dry_run?
        truthy_option?(options[:dry_run]) || truthy_option?(parent_options[:dry_run])
      end

      def effective_verbose?
        truthy_option?(options[:verbose]) || truthy_option?(parent_options[:verbose])
      end

      def truthy_option?(value)
        value == true
      end

      def normalized_modules_option(value)
        Array(value).flat_map { |entry| entry.to_s.split(",") }.map(&:strip).reject(&:empty?).uniq
      end

      def discover_recipe_paths
        Dir.glob(File.join(recipes_root, "*", "recipe.yml"))
      end

      def recipes_root
        File.join(repo_root, "recipes")
      end

      def ui_profile_catalog
        @ui_profile_catalog ||= UIProfileCatalog.new(repository_root: repo_root)
      end

      def repo_root
        File.expand_path("../..", __dir__)
      end

      def resolve_recipe_path(recipe_ref)
        raw = recipe_ref.to_s.strip
        raise InvalidConfiguration, "Recipe value cannot be empty" if raw.empty?

        if raw.end_with?(".yml") || raw.include?(File::SEPARATOR) || raw.start_with?(".", "~")
          path = File.expand_path(raw)
          raise InvalidConfiguration, "Recipe file not found: #{path}" unless File.exist?(path)

          return path
        end

        named_path = File.join(recipes_root, raw, "recipe.yml")
        raise InvalidConfiguration, "Unknown recipe '#{raw}'. Expected #{named_path}" unless File.exist?(named_path)

        named_path
      end
    end

    package_name "railwyrm"

    class_option :no_banner, type: :boolean, default: false, desc: "Hide banner"
    class_option :verbose, type: :boolean, default: false, desc: "Stream command output"
    class_option :dry_run, type: :boolean, default: false, desc: "Print commands without executing"

    desc "recipes SUBCOMMAND ...ARGS", "Recipe definition commands"
    subcommand "recipes", Recipes

    desc "new [APP_NAME]", "Create a new Rails app with the Railwyrm default stack"
    option :path, aliases: "-p", type: :string, default: Dir.pwd, desc: "Workspace path"
    option :interactive, type: :boolean, default: true, desc: "Prompt for app settings"
    option :devise_user_model, type: :string, default: "User", desc: "Devise model name"
    option :sign_in_layout, type: :string, default: "card_combined",
                            desc: "Sign-in layout: simple_minimal, card_combined, split_mockup_quote"
    option :skip_devise_user, type: :boolean, default: false, desc: "Skip creating the Devise model"
    option :devise_confirmable, type: :boolean, default: false, desc: "Enable Devise confirmable module"
    option :devise_lockable, type: :boolean, default: false, desc: "Enable Devise lockable module"
    option :devise_timeoutable, type: :boolean, default: false, desc: "Enable Devise timeoutable module"
    option :devise_two_factor, type: :boolean, default: false, desc: "Enable Devise two-factor authentication"
    option :recipe, type: :string, desc: "Recipe name (e.g. ats) or path to recipe.yml"
    option :with, type: :array, default: [], desc: "Enable optional recipe modules when applying a recipe"
    option :deploy, type: :string, desc: "Deploy preset to apply with the recipe (e.g. render)"
    def new(app_name = nil)
      ui = UI::Console.new(verbose: options[:verbose])
      UI::Banner.new.render unless options[:no_banner]

      config = build_configuration(app_name, ui: ui)
      recipe_option = resolve_recipe_option_for_new(ui: ui)
      recipe = load_recipe_for_new(recipe_option, ui: ui)
      Generator.new(config, ui: ui).run!
      apply_recipe_for_new(
        recipe,
        config,
        ui: ui,
        selected_modules: normalized_modules_option(options[:with]),
        deploy_preset: options[:deploy]
      ) if recipe

      ui.success("Next steps:")
      ui.info("cd #{config.app_path}")
      ui.info("bin/dev")
    rescue StandardError => e
      ui.error(e.message)
      exit(1)
    end

    desc "serve", "Run Railwyrm as a web forge server"
    option :host, type: :string, default: "0.0.0.0", desc: "Host binding"
    option :port, type: :numeric, default: 4567, desc: "Server port"
    option :workspace, aliases: "-w", type: :string, default: Dir.pwd, desc: "Default workspace root"
    def serve
      ui = UI::Console.new(verbose: options[:verbose])
      UI::Banner.new.render unless options[:no_banner]
      ui.headline("Launching Railwyrm Web Forge on http://#{options[:host]}:#{options[:port]}")
      ui.info("Default workspace: #{File.expand_path(options[:workspace])}")

      Server.new(host: options[:host], port: options[:port].to_i, workspace: options[:workspace]).start!
    rescue StandardError => e
      ui.error(e.message)
      exit(1)
    end

    desc "doctor", "Check required dependencies"
    def doctor
      ui = UI::Console.new(verbose: true)
      checks = {
        "ruby" => "ruby -v",
        "bundle" => "bundle -v",
        "rails" => "rails -v",
        "git" => "git --version"
      }

      failures = []
      checks.each do |name, command|
        output, status = run_check(command)

        if status.success?
          ui.success("#{name} found")
          puts output
        else
          failures << name
          ui.warn("#{name} missing or broken")
          ui.stream(output.strip) unless output.strip.empty?
        end
      end

      if failures.empty?
        ui.success("Environment looks ready.")
      else
        ui.error("Missing dependencies: #{failures.join(', ')}")
        exit(1)
      end
    end

    desc "version", "Print Railwyrm version"
    def version
      puts Railwyrm::VERSION
    end

    private

    def run_check(command)
      if defined?(Bundler)
        Bundler.with_unbundled_env { Open3.capture2e(command) }
      else
        Open3.capture2e(command)
      end
    end

    def load_recipe_for_new(recipe_option, ui:)
      return nil if recipe_option.to_s.strip.empty?

      recipe_path = resolve_recipe_path(recipe_option)
      recipe = Recipe.load(recipe_path)
      ui.info("Recipe preflight passed: #{recipe.id}@#{recipe.version} (#{recipe.path})")
      recipe
    end

    def resolve_recipe_option_for_new(ui:)
      explicit = options[:recipe].to_s.strip
      return explicit unless explicit.empty?
      return nil unless options[:interactive]

      prompt = TTY::Prompt.new(interrupt: :exit)
      use_recipe = prompt.yes?("🧩 Apply a recipe after base app generation?", default: false)
      return nil unless use_recipe

      choices = discover_recipe_choices(ui: ui)
      if choices.empty?
        ui.warn("No valid recipes available for wizard selection.")
        return nil
      end

      prompt.select("📚 Select a recipe:") do |menu|
        choices.each do |choice|
          menu.choice choice.fetch(:label), choice.fetch(:value)
        end
      end
    end

    def discover_recipe_choices(ui:)
      discover_recipe_paths.sort.filter_map do |recipe_path|
        begin
          recipe = Recipe.load(recipe_path)
          label = "#{recipe.id}@#{recipe.version} [#{recipe.metadata['status']}] - #{recipe.name}"
          { label: label, value: recipe.path }
        rescue StandardError => e
          ui.warn("Skipping invalid recipe at #{recipe_path}: #{e.message}")
          nil
        end
      end
    end

    def apply_recipe_for_new(recipe, configuration, ui:, selected_modules:, deploy_preset:)
      ui.headline("Applying recipe #{recipe.id}@#{recipe.version}")
      shell = Shell.new(ui: ui, dry_run: configuration.dry_run, verbose: configuration.verbose)
      executor = RecipeExecutor.new(
        recipe,
        workspace: configuration.app_path,
        ui: ui,
        shell: shell,
        dry_run: configuration.dry_run,
        selected_modules: selected_modules,
        deploy_preset: deploy_preset
      )

      executor.plan.each do |step|
        ui.info("#{step.index}. #{step.command}")
      end

      executor.apply!
    end

    def resolve_recipe_path(recipe_option)
      raw = recipe_option.to_s.strip
      raise InvalidConfiguration, "Recipe value cannot be empty" if raw.empty?

      if raw.end_with?(".yml") || raw.include?(File::SEPARATOR) || raw.start_with?(".", "~")
        path = File.expand_path(raw)
        raise InvalidConfiguration, "Recipe file not found: #{path}" unless File.exist?(path)

        return path
      end

      named_path = File.join(repo_root, "recipes", raw, "recipe.yml")
      raise InvalidConfiguration, "Unknown recipe '#{raw}'. Expected #{named_path}" unless File.exist?(named_path)

      named_path
    end

    def discover_recipe_paths
      Dir.glob(File.join(repo_root, "recipes", "*", "recipe.yml"))
    end

    def repo_root
      File.expand_path("../..", __dir__)
    end

    def normalized_modules_option(value)
      Array(value).flat_map { |entry| entry.to_s.split(",") }.map(&:strip).reject(&:empty?).uniq
    end

    def build_configuration(app_name, ui:)
      prompt = TTY::Prompt.new(interrupt: :exit)
      interactive = options[:interactive]

      name = app_name
      workspace = options[:path]
      install_devise_user = !options[:skip_devise_user]
      devise_user_model = options[:devise_user_model]
      sign_in_layout = options[:sign_in_layout]
      devise_confirmable = options[:devise_confirmable]
      devise_lockable = options[:devise_lockable]
      devise_timeoutable = options[:devise_timeoutable]
      devise_two_factor = options[:devise_two_factor]

      if interactive
        name = prompt.ask("⚒️  App name (snake_case):", default: name, required: true)
        workspace = prompt.ask("📁 Workspace path:", default: File.expand_path(workspace), required: true)

        if install_devise_user
          install_devise_user = prompt.yes?("🔐 Generate Devise user model now?", default: true)
          if install_devise_user
            devise_user_model = prompt.ask("🪪 Devise model name:", default: devise_user_model, required: true)
            devise_confirmable = prompt.yes?(
              "✉️ Enable Devise confirmable (email confirmation required)?",
              default: devise_confirmable
            )
            devise_lockable = prompt.yes?(
              "🔒 Enable Devise lockable (lock account after failed attempts)?",
              default: devise_lockable
            )
            devise_timeoutable = prompt.yes?(
              "⏱️ Enable Devise timeoutable (auto sign out inactive users)?",
              default: devise_timeoutable
            )
            devise_two_factor = prompt.yes?(
              "📱 Enable Devise two-factor authentication (TOTP)?",
              default: devise_two_factor
            )
          else
            devise_confirmable = false
            devise_lockable = false
            devise_timeoutable = false
            devise_two_factor = false
          end
        end

        ui.render_sign_in_layout_gallery
        sign_in_layout = prompt.select(
          "🧩 Select sign-in layout:",
          default: sign_in_layout_default_label(sign_in_layout)
        ) do |menu|
          SIGN_IN_LAYOUT_MENU_CHOICES.each do |choice|
            menu.choice choice.fetch(:label), choice.fetch(:value)
          end
        end
      elsif name.nil? || name.strip.empty?
        raise InvalidConfiguration, "APP_NAME is required when --interactive=false"
      end

      Configuration.new(
        name: name,
        workspace: workspace,
        devise_user_model: devise_user_model,
        sign_in_layout: sign_in_layout,
        install_devise_user: install_devise_user,
        devise_confirmable: devise_confirmable,
        devise_lockable: devise_lockable,
        devise_timeoutable: devise_timeoutable,
        devise_two_factor: devise_two_factor,
        dry_run: options[:dry_run],
        verbose: options[:verbose]
      )
    end

    def sign_in_layout_default_label(layout_value)
      selected = SIGN_IN_LAYOUT_MENU_CHOICES.find { |choice| choice.fetch(:value) == layout_value.to_s }
      return selected.fetch(:label) if selected

      SIGN_IN_LAYOUT_MENU_CHOICES.find { |choice| choice.fetch(:value) == "card_combined" }.fetch(:label)
    end
  end
end
