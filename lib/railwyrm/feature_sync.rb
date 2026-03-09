# frozen_string_literal: true

module Railwyrm
  class FeatureSync
    def initialize(app_path:, ui:, dry_run: false, devise_user_model: "User")
      @app_path = File.expand_path(app_path)
      @ui = ui
      @dry_run = dry_run
      @devise_user_model = devise_user_model.to_s.strip.empty? ? "User" : devise_user_model.to_s.strip
    end

    def run!
      status = FeatureStatus.new(app_path: app_path, devise_user_model: devise_user_model).snapshot
      tracked_before = status.fetch(:tracked)
      detected = status.fetch(:detected)

      state.replace!(detected)

      {
        app_path: app_path,
        manifest_path: state.manifest_path,
        dry_run: dry_run,
        changed: tracked_before != detected,
        tracked_before: tracked_before,
        tracked_after: detected,
        added: order_features(detected - tracked_before),
        removed: order_features(tracked_before - detected)
      }
    end

    private

    attr_reader :app_path, :ui, :dry_run, :devise_user_model

    def state
      @state ||= FeatureState.new(app_path: app_path, ui: ui, dry_run: dry_run)
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
