# frozen_string_literal: true

require "open3"

module Railwyrm
  class CLI < Thor
    class Recipes < Thor
      package_name "railwyrm recipes"

      desc "validate [RECIPE_PATH]", "Validate a recipe.yml file against Railwyrm schema v0"
      def validate(recipe_path = "recipe.yml")
        ui = UI::Console.new(verbose: false)
        path = File.expand_path(recipe_path)
        result = RecipeSchema.new.validate_file(path)

        if result.valid?
          ui.success("Recipe is valid: #{path}")
          return
        end

        ui.error("Recipe validation failed: #{path}")
        result.errors.each { |error| ui.warn(error) }
        exit(1)
      end

      desc "plan [RECIPE_PATH]", "Show deterministic execution plan for a recipe"
      option :workspace, aliases: "-w", type: :string, default: Dir.pwd, desc: "Target workspace"
      def plan(recipe_path = "recipe.yml")
        ui = UI::Console.new(verbose: false)
        recipe = load_recipe(recipe_path)
        executor = RecipeExecutor.new(
          recipe,
          workspace: options[:workspace],
          ui: ui,
          shell: Shell.new(ui: ui, dry_run: true, verbose: false)
        )

        ui.headline("Plan for #{recipe.id}@#{recipe.version}")
        ui.info("Recipe file: #{recipe.path}")
        ui.info("Workspace: #{File.expand_path(options[:workspace])}")
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
      def apply(recipe_path = "recipe.yml")
        ui = UI::Console.new(verbose: effective_verbose?)
        recipe = load_recipe(recipe_path)
        shell = Shell.new(ui: ui, dry_run: effective_dry_run?, verbose: effective_verbose?)
        executor = RecipeExecutor.new(recipe, workspace: options[:workspace], ui: ui, shell: shell)
        executor.apply!
      rescue StandardError => e
        ui.error(e.message)
        exit(1)
      end

      private

      def load_recipe(recipe_path)
        Recipe.load(recipe_path)
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
    def new(app_name = nil)
      ui = UI::Console.new(verbose: options[:verbose])
      UI::Banner.new.render unless options[:no_banner]

      config = build_configuration(app_name, ui: ui)
      Generator.new(config, ui: ui).run!

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

    def build_configuration(app_name, ui:)
      prompt = TTY::Prompt.new(interrupt: :exit)
      interactive = options[:interactive]

      name = app_name
      workspace = options[:path]
      install_devise_user = !options[:skip_devise_user]
      devise_user_model = options[:devise_user_model]
      sign_in_layout = options[:sign_in_layout]

      if interactive
        name = prompt.ask("⚒️  App name (snake_case):", default: name, required: true)
        workspace = prompt.ask("📁 Workspace path:", default: File.expand_path(workspace), required: true)

        if install_devise_user
          install_devise_user = prompt.yes?("🔐 Generate Devise user model now?", default: true)
          if install_devise_user
            devise_user_model = prompt.ask("🪪 Devise model name:", default: devise_user_model, required: true)
          end
        end

        ui.render_sign_in_layout_gallery
        sign_in_layout = prompt.select("🧩 Select sign-in layout:", default: sign_in_layout) do |menu|
          menu.choice "Simple Minimal (centered form)", "simple_minimal"
          menu.choice "Card Combined (recommended)", "card_combined"
          menu.choice "Split Mockup Quote (marketing side panel)", "split_mockup_quote"
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
        dry_run: options[:dry_run],
        verbose: options[:verbose]
      )
    end
  end
end
