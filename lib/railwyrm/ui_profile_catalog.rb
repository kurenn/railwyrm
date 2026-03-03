# frozen_string_literal: true

module Railwyrm
  class UIProfileCatalog
    PROFILE_ROOT = File.join("recipes", "_shared", "ui_profiles").freeze
    OVERLAY_TARGETS = [
      { source: "views", destination: "app/views" },
      { source: "components", destination: "app/components" }
    ].freeze

    def initialize(repository_root:)
      @repository_root = File.expand_path(repository_root)
    end

    def list
      return [] unless Dir.exist?(profiles_root)

      Dir.children(profiles_root)
        .select { |entry| File.directory?(File.join(profiles_root, entry)) }
        .sort
    end

    def include?(profile_name)
      normalized = normalize(profile_name)
      return false unless normalized

      list.include?(normalized)
    end

    def overlay_copies_for(profile_name)
      normalized = normalize(profile_name)
      return [] unless normalized

      OVERLAY_TARGETS.map do |target|
        {
          "from" => File.join(PROFILE_ROOT, normalized, target.fetch(:source)),
          "to" => target.fetch(:destination)
        }
      end
    end

    def missing_overlay_paths_for(profile_name)
      overlay_copies_for(profile_name).filter_map do |copy|
        relative_path = copy.fetch("from")
        full_path = File.join(repository_root, relative_path)
        relative_path unless File.exist?(full_path)
      end
    end

    private

    attr_reader :repository_root

    def profiles_root
      File.join(repository_root, PROFILE_ROOT)
    end

    def normalize(profile_name)
      value = profile_name.to_s.strip
      return nil if value.empty?

      value
    end
  end
end
