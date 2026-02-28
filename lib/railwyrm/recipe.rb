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

    def routes
      routes_data = data["routes"]
      return {} unless routes_data.is_a?(Hash)

      routes_data
    end

    def authorization_policies
      policies = data.dig("authorization", "baseline_policies")
      return [] unless policies.is_a?(Array)

      policies
    end

    def allowed_modules
      allowed = data.dig("inputs", "with_modules", "allowed")
      return [] unless allowed.is_a?(Array)

      allowed
    end

    def default_modules
      defaults = data.dig("inputs", "with_modules", "default")
      return [] unless defaults.is_a?(Array)

      defaults
    end

    def resolve_modules(selection)
      requested = normalize_module_selection(selection)
      requested = default_modules if requested.empty?
      return [] if requested.empty?

      unknown = requested - allowed_modules
      unless unknown.empty?
        raise InvalidConfiguration,
              "Unknown recipe module(s): #{unknown.join(', ')}. Allowed: #{allowed_modules.join(', ')}"
      end

      # Keep deterministic ordering aligned to recipe contract.
      allowed_modules.select { |mod| requested.include?(mod) }
    end

    def module_gems(selected_modules)
      selected = resolve_modules(selected_modules)
      return [] if selected.empty?

      optional = data.dig("gems", "optional_by_module")
      return [] unless optional.is_a?(Hash)

      selected.flat_map do |mod|
        entries = optional[mod]
        next [] unless entries.is_a?(Array)

        entries.filter_map do |entry|
          next unless entry.is_a?(Hash)

          name = entry["name"].to_s.strip
          name.empty? ? nil : name
        end
      end.uniq
    end

    def module_setup_commands(selected_modules)
      selected = resolve_modules(selected_modules)
      return [] if selected.empty?

      setup = data["module_setup"]
      return [] unless setup.is_a?(Hash)

      selected.flat_map do |mod|
        commands = setup.dig(mod, "commands")
        commands.is_a?(Array) ? commands : []
      end
    end

    def deploy_preset_names
      presets = data.dig("deploy", "presets")
      return [] unless presets.is_a?(Hash)

      presets.keys
    end

    def deploy_preset(deploy_name)
      name = deploy_name.to_s.strip
      return nil if name.empty?

      presets = data.dig("deploy", "presets")
      unless presets.is_a?(Hash) && presets.key?(name)
        raise InvalidConfiguration,
              "Unknown deploy preset '#{name}'. Allowed: #{deploy_preset_names.join(', ')}"
      end

      presets[name]
    end

    def deploy_copy_entries(deploy_name)
      preset = deploy_preset(deploy_name)
      return [] unless preset.is_a?(Hash)

      copies = preset["copies"]
      copies.is_a?(Array) ? copies : []
    end

    def deploy_smoke_commands(deploy_name)
      preset = deploy_preset(deploy_name)
      return [] unless preset.is_a?(Hash)

      commands = preset["smoke_commands"]
      commands.is_a?(Array) ? commands : []
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

    def normalize_module_selection(selection)
      Array(selection).flat_map do |entry|
        entry.to_s.split(",")
      end.map(&:strip).reject(&:empty?).uniq
    end

    def repository_root
      marker = "#{File::SEPARATOR}recipes#{File::SEPARATOR}"
      marker_index = path.index(marker)
      return File.dirname(path) unless marker_index

      path[0...marker_index]
    end
  end
end
