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

    class Features < Thor
      package_name "railwyrm feature"

      desc "list", "List installable features for existing Rails apps"
      def list
        ui = UI::Console.new(verbose: false)
        ui.headline("Installable features")

        FeatureRegistry.list.each do |feature_name|
          metadata = FeatureRegistry.fetch(feature_name)
          dependencies = metadata.fetch(:dependencies)
          dependency_label = dependencies.empty? ? "none" : dependencies.join(", ")
          ui.info("#{feature_name} - #{metadata.fetch(:description)}")
          ui.info("  dependencies: #{dependency_label}")
        end
      end

      desc "install FEATURE [FEATURE ...]", "Install one or more features into an existing Rails app"
      option :app, aliases: "-a", type: :string, default: Dir.pwd, desc: "Path to existing Rails app"
      option :devise_user_model, type: :string, default: "User", desc: "Devise model name"
      option :verbose, type: :boolean, default: false, desc: "Stream command output"
      option :dry_run, aliases: "--dry_run", type: :boolean, default: false,
                        desc: "Print commands without executing"
      def install(*features)
        ui = UI::Console.new(verbose: options[:verbose])
        normalized = normalize_features(features)
        shell = Shell.new(ui: ui, dry_run: options[:dry_run], verbose: options[:verbose])

        installer = FeatureInstaller.new(
          app_path: options[:app],
          ui: ui,
          shell: shell,
          dry_run: options[:dry_run],
          devise_user_model: options[:devise_user_model]
        )
        installer.install!(normalized)
      rescue StandardError => e
        ui.error(e.message)
        exit(1)
      end

      desc "status", "Show feature tracking and detection status for an existing Rails app"
      option :app, aliases: "-a", type: :string, default: Dir.pwd, desc: "Path to existing Rails app"
      option :devise_user_model, type: :string, default: "User", desc: "Devise model name"
      def status
        ui = UI::Console.new(verbose: false)
        summary = FeatureStatus.new(
          app_path: options[:app],
          devise_user_model: options[:devise_user_model]
        ).snapshot

        ui.headline("Feature status for #{summary.fetch(:app_path)}")
        ui.info("Manifest: #{summary.fetch(:manifest_path)}")
        ui.info("installed: #{format_feature_list(summary.fetch(:installed))}")
        ui.warn("tracked_only: #{format_feature_list(summary.fetch(:tracked_only))}") unless summary.fetch(:tracked_only).empty?
        ui.warn("detected_only: #{format_feature_list(summary.fetch(:detected_only))}") unless summary.fetch(:detected_only).empty?
        ui.info("available: #{format_feature_list(summary.fetch(:available))}")
      rescue StandardError => e
        ui.error(e.message)
        exit(1)
      end

      desc "sync", "Rebuild feature manifest from detected app state"
      option :app, aliases: "-a", type: :string, default: Dir.pwd, desc: "Path to existing Rails app"
      option :devise_user_model, type: :string, default: "User", desc: "Devise model name"
      option :dry_run, aliases: "--dry_run", type: :boolean, default: false,
                        desc: "Print intended changes without writing files"
      def sync
        ui = UI::Console.new(verbose: false)
        result = FeatureSync.new(
          app_path: options[:app],
          ui: ui,
          dry_run: options[:dry_run],
          devise_user_model: options[:devise_user_model]
        ).run!

        ui.headline("Feature sync for #{result.fetch(:app_path)}")
        ui.info("Manifest: #{result.fetch(:manifest_path)}")
        ui.info("added: #{format_feature_list(result.fetch(:added))}")
        ui.info("removed: #{format_feature_list(result.fetch(:removed))}")
        ui.info("tracked_after: #{format_feature_list(result.fetch(:tracked_after))}")

        if result.fetch(:changed)
          if result.fetch(:dry_run)
            ui.warn("Dry run: manifest was not updated.")
          else
            ui.success("Feature manifest synchronized.")
          end
        else
          ui.success("Feature manifest already synchronized.")
        end
      rescue StandardError => e
        ui.error(e.message)
        exit(1)
      end

      private

      def normalize_features(values)
        Array(values).flat_map { |value| value.to_s.split(",") }.map(&:strip).reject(&:empty?).uniq
      end

      def format_feature_list(values)
        list = Array(values)
        return "none" if list.empty?

        list.join(", ")
      end
    end

    package_name "railwyrm"

    class_option :no_banner, type: :boolean, default: false, desc: "Hide banner"
    class_option :verbose, type: :boolean, default: false, desc: "Stream command output"
    class_option :dry_run, type: :boolean, default: false, desc: "Print commands without executing"

    desc "feature SUBCOMMAND ...ARGS", "Install features into an existing Rails app"
    subcommand "feature", Features

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
    option :devise_trackable, type: :boolean, default: false, desc: "Enable Devise trackable module"
    option :devise_magic_link, type: :boolean, default: false, desc: "Enable magic-link sign-in via email"
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
      devise_confirmable = options[:devise_confirmable]
      devise_lockable = options[:devise_lockable]
      devise_timeoutable = options[:devise_timeoutable]
      devise_trackable = options[:devise_trackable]
      devise_magic_link = options[:devise_magic_link]

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
            devise_trackable = prompt.yes?(
              "📈 Enable Devise trackable (track sign in count, timestamps, and IPs)?",
              default: devise_trackable
            )
            devise_magic_link = prompt.yes?(
              "✨ Enable magic-link sign-in by email?",
              default: devise_magic_link
            )
          else
            devise_confirmable = false
            devise_lockable = false
            devise_timeoutable = false
            devise_trackable = false
            devise_magic_link = false
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

      if devise_magic_link && !devise_trackable
        ui.info("Magic-link sign-in requires Devise trackable; enabling trackable automatically.")
        devise_trackable = true
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
        devise_trackable: devise_trackable,
        devise_magic_link: devise_magic_link,
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
