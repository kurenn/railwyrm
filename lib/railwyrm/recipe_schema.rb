# frozen_string_literal: true

require "yaml"

module Railwyrm
  class RecipeSchema
    Result = Struct.new(:errors, keyword_init: true) do
      def valid?
        errors.empty?
      end
    end

    REQUIRED_TOP_LEVEL_KEYS = %w[
      id
      name
      version
      status
      description
      base_stack
      inputs
      roles
      gems
      data_model
      scaffolding_plan
      ui_overlays
      routes
      authorization
      seed_data
      quality_gates
      ai_assets
    ].freeze

    OPTIONAL_TOP_LEVEL_KEYS = %w[
      ui_profile
      module_setup
      deploy
    ].freeze

    ALLOWED_TOP_LEVEL_KEYS = (REQUIRED_TOP_LEVEL_KEYS + OPTIONAL_TOP_LEVEL_KEYS).freeze

    def validate_file(path)
      data = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
      validate(data)
    rescue Psych::SyntaxError => e
      Result.new(errors: ["YAML parse error: #{e.message.lines.first.to_s.strip}"])
    rescue Errno::ENOENT
      Result.new(errors: ["Recipe file not found: #{path}"])
    end

    def validate(data)
      errors = []

      unless data.is_a?(Hash)
        return Result.new(errors: ["Top-level YAML value must be a mapping"])
      end

      keys = data.keys.map(&:to_s)
      missing = REQUIRED_TOP_LEVEL_KEYS - keys
      unknown = keys - ALLOWED_TOP_LEVEL_KEYS

      missing.each { |key| errors << "Missing required key: #{key}" }
      unknown.each { |key| errors << "Unknown top-level key: #{key}" }

      validate_string(data, "id", errors)
      validate_string(data, "name", errors)
      validate_string(data, "version", errors)
      validate_string(data, "status", errors)
      validate_string(data, "description", errors)
      validate_optional_string(data, "ui_profile", errors)

      validate_base_stack(data["base_stack"], errors)
      validate_inputs(data["inputs"], errors)
      validate_string_array(data["roles"], "roles", errors, min_size: 1)
      validate_gems(data["gems"], errors)
      validate_data_model(data["data_model"], errors)
      validate_scaffolding_plan(data["scaffolding_plan"], errors)
      validate_ui_overlays(data["ui_overlays"], errors)
      validate_routes(data["routes"], errors)
      validate_authorization(data["authorization"], errors)
      validate_seed_data(data["seed_data"], errors)
      validate_quality_gates(data["quality_gates"], errors)
      validate_ai_assets(data["ai_assets"], errors)
      validate_module_setup(data["module_setup"], errors)
      validate_deploy(data["deploy"], errors)

      Result.new(errors: errors.uniq)
    end

    private

    def validate_string(data, key, errors)
      value = data[key]
      return if value.is_a?(String) && !value.strip.empty?

      errors << "#{key} must be a non-empty string"
    end

    def validate_optional_string(data, key, errors)
      return unless data.key?(key)

      value = data[key]
      return if value.is_a?(String) && !value.strip.empty?

      errors << "#{key} must be a non-empty string when present"
    end

    def validate_string_array(value, key, errors, min_size: 0)
      unless value.is_a?(Array)
        errors << "#{key} must be an array"
        return
      end

      if value.size < min_size
        errors << "#{key} must contain at least #{min_size} item(s)"
      end

      unless value.all? { |entry| entry.is_a?(String) && !entry.strip.empty? }
        errors << "#{key} must contain only non-empty strings"
      end
    end

    def validate_base_stack(value, errors)
      unless value.is_a?(Hash)
        errors << "base_stack must be a mapping"
        return
      end

      source = value["source"]
      requires = value["requires"]

      errors << "base_stack.source must be a non-empty string" unless source.is_a?(String) && !source.strip.empty?
      validate_string_array(requires, "base_stack.requires", errors, min_size: 1)
    end

    def validate_inputs(value, errors)
      unless value.is_a?(Hash)
        errors << "inputs must be a mapping"
        return
      end

      value.each do |input_name, spec|
        unless spec.is_a?(Hash)
          errors << "inputs.#{input_name} must be a mapping"
          next
        end

        type = spec["type"]
        required = spec["required"]

        unless %w[string array integer boolean].include?(type)
          errors << "inputs.#{input_name}.type must be one of: string, array, integer, boolean"
        end

        errors << "inputs.#{input_name}.required must be boolean" unless [true, false].include?(required)

        next unless input_name.to_s == "with_modules"

        validate_string_array(spec["allowed"], "inputs.with_modules.allowed", errors, min_size: 1)

        default = spec["default"]
        unless default.is_a?(Array) && default.all? { |entry| entry.is_a?(String) && !entry.strip.empty? }
          errors << "inputs.with_modules.default must be an array of non-empty strings"
          next
        end

        allowed = spec["allowed"]
        next unless allowed.is_a?(Array)

        unknown = default - allowed
        errors << "inputs.with_modules.default includes unknown module(s): #{unknown.join(', ')}" unless unknown.empty?
      end
    end

    def validate_gems(value, errors)
      unless value.is_a?(Hash)
        errors << "gems must be a mapping"
        return
      end

      required = value["required"]
      validate_named_entries(required, "gems.required", errors)

      optional_by_module = value["optional_by_module"]
      if optional_by_module && !optional_by_module.is_a?(Hash)
        errors << "gems.optional_by_module must be a mapping when present"
      elsif optional_by_module
        optional_by_module.each do |mod_name, entries|
          validate_named_entries(entries, "gems.optional_by_module.#{mod_name}", errors)
        end
      end
    end

    def validate_named_entries(entries, key, errors)
      unless entries.is_a?(Array)
        errors << "#{key} must be an array"
        return
      end

      entries.each_with_index do |entry, index|
        unless entry.is_a?(Hash) && entry["name"].is_a?(String) && !entry["name"].strip.empty?
          errors << "#{key}[#{index}] must include a non-empty name"
        end
      end
    end

    def validate_data_model(value, errors)
      unless value.is_a?(Hash)
        errors << "data_model must be a mapping"
        return
      end

      models = value["models"]
      unless models.is_a?(Hash) && !models.empty?
        errors << "data_model.models must be a non-empty mapping"
      end
    end

    def validate_scaffolding_plan(value, errors)
      unless value.is_a?(Hash)
        errors << "scaffolding_plan must be a mapping"
        return
      end

      validate_string_array(value["commands"], "scaffolding_plan.commands", errors, min_size: 1)
    end

    def validate_ui_overlays(value, errors)
      unless value.is_a?(Hash)
        errors << "ui_overlays must be a mapping"
        return
      end

      copies = value["copies"]
      validate_copy_entries(copies, "ui_overlays.copies", errors)
    end

    def validate_routes(value, errors)
      unless value.is_a?(Hash)
        errors << "routes must be a mapping"
        return
      end

      validate_route_entries(value["authenticated"], "routes.authenticated", errors)
      validate_route_entries(value["public"], "routes.public", errors)
    end

    def validate_route_entries(entries, key, errors)
      unless entries.is_a?(Array)
        errors << "#{key} must be an array"
        return
      end

      entries.each_with_index do |entry, index|
        unless entry.is_a?(Hash) && entry["type"].is_a?(String) && !entry["type"].strip.empty?
          errors << "#{key}[#{index}] must include a non-empty type"
          next
        end

        type = entry["type"]
        unless %w[root get resources].include?(type)
          errors << "#{key}[#{index}].type must be one of: root, get, resources"
          next
        end

        case type
        when "root"
          target = entry["to"]
          errors << "#{key}[#{index}].to must be a non-empty string for root routes" unless target.is_a?(String) && !target.strip.empty?
        when "get"
          path = entry["path"]
          target = entry["to"]
          errors << "#{key}[#{index}].path must be a non-empty string for get routes" unless path.is_a?(String) && !path.strip.empty?
          errors << "#{key}[#{index}].to must be a non-empty string for get routes" unless target.is_a?(String) && !target.strip.empty?
        when "resources"
          resource_name = entry["name"]
          unless resource_name.is_a?(String) && !resource_name.strip.empty?
            errors << "#{key}[#{index}].name must be a non-empty string for resources routes"
          end

          only = entry["only"]
          validate_string_array(only, "#{key}[#{index}].only", errors, min_size: 1) if entry.key?("only")

          controller = entry["controller"]
          if entry.key?("controller") && !(controller.is_a?(String) && !controller.strip.empty?)
            errors << "#{key}[#{index}].controller must be a non-empty string when present"
          end

          nested = entry["nested"]
          if entry.key?("nested")
            validate_route_entries(nested, "#{key}[#{index}].nested", errors)
          end
        end
      end
    end

    def validate_authorization(value, errors)
      unless value.is_a?(Hash)
        errors << "authorization must be a mapping"
        return
      end

      policy_system = value["policy_system"]
      errors << "authorization.policy_system must be a non-empty string" unless policy_system.is_a?(String) && !policy_system.strip.empty?
      validate_string_array(value["baseline_policies"], "authorization.baseline_policies", errors, min_size: 1)
    end

    def validate_seed_data(value, errors)
      unless value.is_a?(Hash)
        errors << "seed_data must be a mapping"
        return
      end

      create_demo_data = value["create_demo_data"]
      errors << "seed_data.create_demo_data must be boolean" unless [true, false].include?(create_demo_data)
      validate_string_array(value["fixtures"], "seed_data.fixtures", errors, min_size: 1)
      file = value["file"]
      errors << "seed_data.file must be a non-empty string" unless file.is_a?(String) && !file.strip.empty?
    end

    def validate_quality_gates(value, errors)
      unless value.is_a?(Hash)
        errors << "quality_gates must be a mapping"
        return
      end

      validate_string_array(value["required_commands"], "quality_gates.required_commands", errors, min_size: 1)
      validate_string_array(value["acceptance_checks"], "quality_gates.acceptance_checks", errors, min_size: 1)
    end

    def validate_ai_assets(value, errors)
      unless value.is_a?(Hash)
        errors << "ai_assets must be a mapping"
        return
      end

      %w[agents skills prompts playbooks].each do |key|
        validate_string_array(value[key], "ai_assets.#{key}", errors, min_size: 1)
      end
    end

    def validate_module_setup(value, errors)
      return if value.nil?

      unless value.is_a?(Hash)
        errors << "module_setup must be a mapping when present"
        return
      end

      value.each do |module_name, spec|
        unless spec.is_a?(Hash)
          errors << "module_setup.#{module_name} must be a mapping"
          next
        end

        validate_string_array(spec["commands"], "module_setup.#{module_name}.commands", errors, min_size: 1)
      end
    end

    def validate_deploy(value, errors)
      return if value.nil?

      unless value.is_a?(Hash)
        errors << "deploy must be a mapping when present"
        return
      end

      presets = value["presets"]
      unless presets.is_a?(Hash) && !presets.empty?
        errors << "deploy.presets must be a non-empty mapping"
        return
      end

      presets.each do |preset_name, spec|
        unless spec.is_a?(Hash)
          errors << "deploy.presets.#{preset_name} must be a mapping"
          next
        end

        copies = spec["copies"]
        smoke_commands = spec["smoke_commands"]

        if copies.nil? && smoke_commands.nil?
          errors << "deploy.presets.#{preset_name} must include copies and/or smoke_commands"
          next
        end

        validate_copy_entries(copies, "deploy.presets.#{preset_name}.copies", errors) unless copies.nil?
        validate_string_array(
          smoke_commands,
          "deploy.presets.#{preset_name}.smoke_commands",
          errors,
          min_size: 1
        ) unless smoke_commands.nil?
      end
    end

    def validate_copy_entries(copies, key, errors)
      unless copies.is_a?(Array)
        errors << "#{key} must be an array"
        return
      end

      copies.each_with_index do |copy, index|
        unless copy.is_a?(Hash)
          errors << "#{key}[#{index}] must be a mapping"
          next
        end

        from = copy["from"]
        to = copy["to"]
        errors << "#{key}[#{index}].from must be a non-empty string" unless from.is_a?(String) && !from.strip.empty?
        errors << "#{key}[#{index}].to must be a non-empty string" unless to.is_a?(String) && !to.strip.empty?
      end
    end
  end
end
