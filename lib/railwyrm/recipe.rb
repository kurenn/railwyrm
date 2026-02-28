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
  end
end
