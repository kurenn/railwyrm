# frozen_string_literal: true

module Railwyrm
  class FeatureStatus
    def initialize(app_path:, devise_user_model: "User")
      @app_path = File.expand_path(app_path)
      @devise_user_model = devise_user_model.to_s.strip.empty? ? "User" : devise_user_model.to_s.strip
    end

    def snapshot
      ensure_app_path!

      state = FeatureState.new(app_path: app_path, ui: UI::Buffer.new)
      tracked = state.tracked_features
      detected = FeatureDetector.new(app_path: app_path, devise_user_model: devise_user_model).detect
      available = FeatureRegistry.list

      {
        app_path: app_path,
        manifest_path: state.manifest_path,
        available: available,
        tracked: tracked,
        detected: detected,
        installed: order_features(tracked & detected),
        tracked_only: order_features(tracked - detected),
        detected_only: order_features(detected - tracked)
      }
    end

    private

    attr_reader :app_path, :devise_user_model

    def ensure_app_path!
      raise InvalidConfiguration, "Rails app path not found: #{app_path}" unless Dir.exist?(app_path)

      gemfile_path = File.join(app_path, "Gemfile")
      raise InvalidConfiguration, "Gemfile not found at #{gemfile_path}" unless File.exist?(gemfile_path)
    end

    def order_features(features)
      values = Array(features).map(&:to_s).map(&:strip).reject(&:empty?).uniq
      known_order = FeatureRegistry.list
      known = known_order.select { |name| values.include?(name) }
      unknown = (values - known_order).sort
      known + unknown
    end
  end
end
