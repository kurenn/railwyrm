# frozen_string_literal: true

require "yaml"

module Railwyrm
  class Recipe
    attr_reader :path, :data

    def self.load(path)
      absolute_path = File.expand_path(path)
      schema_result = RecipeSchema.new.validate_file(absolute_path)
      unless schema_result.valid?
        message = "Invalid recipe at #{absolute_path}:\n- #{schema_result.errors.join("\n- ")}"
        raise InvalidConfiguration, message
      end

      data = YAML.safe_load(File.read(absolute_path), permitted_classes: [], aliases: false)
      new(path: absolute_path, data: data)
    end

    def initialize(path:, data:)
      @path = path
      @data = data
    end

    def id
      data.fetch("id")
    end

    def name
      data.fetch("name")
    end

    def version
      data.fetch("version")
    end

    def scaffolding_commands
      data.fetch("scaffolding_plan").fetch("commands")
    end

    def ui_overlay_copies
      data.fetch("ui_overlays").fetch("copies")
    end

    def seed_data_file
      data.fetch("seed_data").fetch("file")
    end

    def quality_gate_commands
      quality_gates = data["quality_gates"]
      return [] unless quality_gates.is_a?(Hash)

      commands = quality_gates["required_commands"]
      return [] unless commands.is_a?(Array)

      commands
    end

    def metadata
      {
        "id" => data["id"],
        "name" => data["name"],
        "version" => data["version"],
        "status" => data["status"],
        "description" => data["description"]
      }
    end

    def resolve_reference_path(reference)
      return File.expand_path(reference) if reference.start_with?("/", "./", "../")

      if reference.start_with?("recipes/")
        File.expand_path(reference, repository_root)
      else
        File.expand_path(reference, File.dirname(path))
      end
    end

    private

    def repository_root
      marker = "#{File::SEPARATOR}recipes#{File::SEPARATOR}"
      marker_index = path.index(marker)
      return File.dirname(path) unless marker_index

      path[0...marker_index]
    end
  end
end
