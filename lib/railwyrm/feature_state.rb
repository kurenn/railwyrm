# frozen_string_literal: true

require "fileutils"
require "time"
require "yaml"

module Railwyrm
  class FeatureState
    SCHEMA_VERSION = 1
    MANIFEST_RELATIVE_PATH = ".railwyrm/features.yml"

    def initialize(app_path:, ui:, dry_run: false)
      @app_path = File.expand_path(app_path)
      @ui = ui
      @dry_run = dry_run
    end

    def manifest_path
      File.join(app_path, MANIFEST_RELATIVE_PATH)
    end

    def manifest_exists?
      File.exist?(manifest_path)
    end

    def tracked_features
      read_manifest.fetch("features")
    end

    def mark_installed!(feature_names)
      merged = normalize_feature_names(tracked_features + Array(feature_names))
      write_manifest!(merged)
    end

    def replace!(feature_names)
      write_manifest!(normalize_feature_names(feature_names))
    end

    private

    attr_reader :app_path, :ui, :dry_run

    def read_manifest
      return default_manifest unless manifest_exists?

      parsed = YAML.safe_load(File.read(manifest_path), permitted_classes: [], aliases: false)
      unless parsed.is_a?(Hash)
        raise InvalidConfiguration, "Invalid feature manifest format at #{manifest_path}"
      end

      {
        "version" => parsed["version"] || SCHEMA_VERSION,
        "features" => normalize_feature_names(parsed["features"])
      }
    rescue Psych::SyntaxError => e
      raise InvalidConfiguration, "Invalid feature manifest YAML at #{manifest_path}: #{e.message}"
    end

    def write_manifest!(features)
      if dry_run
        ui.info("Dry run enabled: feature manifest write skipped.")
        return features
      end

      current = tracked_features
      return current if current == features && manifest_exists?

      FileUtils.mkdir_p(File.dirname(manifest_path))
      File.write(
        manifest_path,
        YAML.dump(
          {
            "version" => SCHEMA_VERSION,
            "features" => features,
            "updated_at" => Time.now.utc.iso8601
          }
        )
      )
      features
    end

    def normalize_feature_names(feature_names)
      Array(feature_names).each_with_object([]) do |value, normalized|
        name = value.to_s.strip
        next if name.empty? || normalized.include?(name)

        normalized << name
      end
    end

    def default_manifest
      {
        "version" => SCHEMA_VERSION,
        "features" => []
      }
    end
  end
end
