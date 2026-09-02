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
          patcher.enable_optional_devise_modules!(module_features)
        end
      end

      if features.include?("magic_link")
        ui.step("Install magic-link authentication") do
          patcher.enable_magic_link_authentication!
        end
      end

      if features.include?("passkeys")
        ui.step("Install passkeys authentication") do
          patcher.enable_passkeys_authentication!
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

    def enable_ci_workflow!
      if dry_run
        ui.info("Dry run enabled: CI workflow setup skipped.")
        return
      end

      patcher.ensure_ci_workflow_file!
    end

    def enable_quality_tooling!
      if dry_run
        ui.info("Dry run enabled: quality tooling setup skipped.")
        return
      end

      patcher.ensure_bullet_development_configuration!
    end

    def patcher
      @patcher ||= AppPatcher.new(
        app_path: app_path,
        ui: ui,
        shell: shell,
        dry_run: dry_run,
        devise_user_model: devise_user_model
      )
    end

    def feature_state
      @feature_state ||= FeatureState.new(app_path: app_path, ui: ui, dry_run: dry_run)
    end

    def feature_detector
      @feature_detector ||= FeatureDetector.new(app_path: app_path, devise_user_model: devise_user_model)
    end

  end
end
