# frozen_string_literal: true

require "fileutils"
require "shellwords"
require "set"

module Railwyrm
  class RecipeExecutor
    Step = Struct.new(:index, :command, keyword_init: true)

    def initialize(recipe, workspace:, ui:, shell:, dry_run: false, selected_modules: [], deploy_preset: nil)
      @recipe = recipe
      @workspace = File.expand_path(workspace)
      @ui = ui
      @shell = shell
      @dry_run = dry_run
      @selected_modules = recipe.resolve_modules(selected_modules)
      @deploy_preset = normalized_deploy_preset(deploy_preset)
      recipe.deploy_preset(@deploy_preset) if @deploy_preset
    end

    def plan
      command_list.each_with_index.map do |command, index|
        Step.new(index: index + 1, command: command)
      end
    end

    def apply!
      ensure_workspace!
      scaffold_steps = recipe.scaffolding_commands

      ui.headline("Applying recipe #{recipe.id}@#{recipe.version} in #{workspace}")
      ui.step("Install recipe gems") do
        apply_recipe_gems!
      end

      scaffold_steps.each_with_index do |command, index|
        ui.step("Recipe step #{index + 1}/#{scaffold_steps.length}") do
          shell.run!(*Shellwords.split(command), chdir: workspace)
        end
      end

      run_module_setup_commands!

      ui.step("Apply recipe UI overlays") do
        apply_ui_overlays!
      end

      ui.step("Install recipe seeds") do
        install_seed_data!
      end

      ui.step("Wire routes, controllers, and policies") do
        apply_app_wiring!
      end

      ui.step("Apply deploy preset") do
        apply_deploy_preset!
      end

      run_quality_gates!
      run_deploy_smoke_checks!

      ui.success("Recipe apply complete for #{recipe.id}")
      true
    end

    private

    attr_reader :recipe, :workspace, :ui, :shell, :dry_run, :selected_modules, :deploy_preset

    def command_list
      commands = []
      commands << "bundle install" unless recipe.recipe_gems(selected_modules).empty?
      commands.concat(recipe.scaffolding_commands)
      commands.concat(recipe.module_setup_commands(selected_modules))
      commands.concat(recipe.quality_gate_commands)
      commands.concat(recipe.deploy_smoke_commands(deploy_preset)) if deploy_preset

      commands
    end

    def normalized_deploy_preset(deploy_name)
      value = deploy_name.to_s.strip
      value.empty? ? nil : value
    end

    def ensure_workspace!
      return if dry_run

      raise InvalidConfiguration, "Workspace does not exist: #{workspace}" unless Dir.exist?(workspace)
    end

    def apply_recipe_gems!
      gems = recipe.recipe_gems(selected_modules)
      if gems.empty?
        ui.info("No recipe gems to install")
        return
      end

      gemfile_path = File.join(workspace, "Gemfile")
      unless dry_run || File.exist?(gemfile_path)
        raise InvalidConfiguration, "Gemfile not found at #{gemfile_path}"
      end

      if dry_run
        ui.info("Dry run: ensure gems #{gems.join(', ')} in Gemfile")
        ui.info("Dry run: run bundle install for recipe gems")
        return
      end

      gemfile = File.read(gemfile_path)
      missing = gems.reject { |name| gemfile.match?(/^\s*gem\s+['"]#{Regexp.escape(name)}['"]/) }
      if missing.empty?
        ui.info("Module gems already present in Gemfile")
      else
        updated = "#{gemfile.rstrip}\n\n#{missing.map { |name| %(gem "#{name}") }.join("\n")}\n"
        File.write(gemfile_path, updated)
      end

      shell.run!("bundle", "install", chdir: workspace)
    end

    def run_module_setup_commands!
      commands = recipe.module_setup_commands(selected_modules)
      return if commands.empty?

      ui.headline("Running module setup for #{recipe.id}")
      commands.each_with_index do |command, index|
        ui.step("Module setup #{index + 1}/#{commands.length}") do
          shell.run!(*Shellwords.split(command), chdir: workspace)
        end
      end
    end

    def apply_ui_overlays!
      copy_reference_entries!(recipe.ui_overlay_copies, label: "UI overlay")
    end

    def apply_deploy_preset!
      unless deploy_preset
        ui.info("No deploy preset selected")
        return
      end

      copies = recipe.deploy_copy_entries(deploy_preset)
      if copies.empty?
        ui.info("Deploy preset #{deploy_preset} has no file copies")
        return
      end

      copy_reference_entries!(copies, label: "deploy preset #{deploy_preset}")
    end

    def install_seed_data!
      source = recipe.resolve_reference_path(recipe.seed_data_file)
      raise InvalidConfiguration, "Seed data source does not exist: #{source}" unless File.exist?(source)

      destination = File.join(workspace, "db", "seeds", "#{recipe.id}.seeds.rb")
      loader_line = "load Rails.root.join(\"db/seeds/#{recipe.id}.seeds.rb\")"

      if dry_run
        ui.info("Dry run: copy #{source} -> #{destination}")
        ui.info("Dry run: ensure #{loader_line} in db/seeds.rb")
        return
      end

      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)

      seeds_path = File.join(workspace, "db", "seeds.rb")
      seeds_content = File.exist?(seeds_path) ? File.read(seeds_path) : ""
      return if seeds_content.include?(loader_line)

      joined = seeds_content.rstrip
      updated = joined.empty? ? "#{loader_line}\n" : "#{joined}\n#{loader_line}\n"
      File.write(seeds_path, updated)
    end

    def run_quality_gates!
      commands = recipe.quality_gate_commands
      return if commands.empty?

      ui.headline("Running quality gates for #{recipe.id}")
      commands.each_with_index do |command, index|
        ui.step("Quality gate #{index + 1}/#{commands.length}") do
          shell.run!(*Shellwords.split(command), chdir: workspace)
        end
      end
    end

    def run_deploy_smoke_checks!
      return unless deploy_preset

      commands = recipe.deploy_smoke_commands(deploy_preset)
      return if commands.empty?

      ui.headline("Running deploy smoke checks for #{deploy_preset}")
      commands.each_with_index do |command, index|
        ui.step("Deploy smoke #{index + 1}/#{commands.length}") do
          shell.run!(*Shellwords.split(command), chdir: workspace)
        end
      end
    end

    def copy_reference_entries!(copies, label:)
      copies.each do |copy|
        source = recipe.resolve_reference_path(copy.fetch("from"))
        destination_root = File.join(workspace, copy.fetch("to"))
        unless File.exist?(source)
          raise InvalidConfiguration, "#{label} source does not exist: #{source}"
        end

        if dry_run
          ui.info("Dry run: copy #{source} -> #{destination_root}")
          next
        end

        if File.directory?(source)
          copy_directory_contents(source, destination_root)
        else
          FileUtils.mkdir_p(File.dirname(destination_root))
          FileUtils.cp(source, destination_root)
        end
      end
    end

    def copy_directory_contents(source, destination_root)
      FileUtils.mkdir_p(destination_root)
      Dir.glob(File.join(source, "**", "*"), File::FNM_DOTMATCH).sort.each do |entry|
        basename = File.basename(entry)
        next if basename == "." || basename == ".."

        relative_path = entry.delete_prefix("#{source}/")
        destination = File.join(destination_root, relative_path)

        if File.directory?(entry)
          FileUtils.mkdir_p(destination)
        else
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(entry, destination)
        end
      end
    end

    def apply_app_wiring!
      apply_routes_file!
      ensure_controller_files!
      ensure_policy_files!
    end

    def routes_path
      File.join(workspace, "config/routes.rb")
    end

    def route_block_start_marker
      "# BEGIN railwyrm:recipe:#{recipe.id}"
    end

    def route_block_end_marker
      "# END railwyrm:recipe:#{recipe.id}"
    end

    def apply_routes_file!
      fragment = build_recipe_routes_fragment
      return if fragment.strip.empty?

      if dry_run
        ui.info("Dry run: ensure recipe routes block in #{routes_path}")
        return
      end

      raise InvalidConfiguration, "Routes file not found: #{routes_path}" unless File.exist?(routes_path)

      content = File.read(routes_path)
      updated = if content.include?(route_block_start_marker)
                  replace_existing_route_block(content, fragment)
                else
                  insert_route_block(content, fragment)
                end

      File.write(routes_path, updated) unless updated == content
    end

    def replace_existing_route_block(content, fragment)
      pattern = /
        #{Regexp.escape(route_block_start_marker)}\n
        .*?
        #{Regexp.escape(route_block_end_marker)}\n?
      /mx
      content.sub(pattern, fragment)
    end

    def insert_route_block(content, fragment)
      if content =~ /\nend\s*\z/
        insert_index = Regexp.last_match.begin(0)
        content.dup.insert(insert_index, "\n#{fragment}\n")
      else
        "#{content.rstrip}\n\n#{fragment}\n"
      end
    end

    def build_recipe_routes_fragment
      lines = []
      authenticated_entries = route_entries("authenticated")
      public_entries = route_entries("public")
      has_public_root = public_entries.any? { |entry| entry["type"].to_s == "root" }

      unless has_public_root
        lines << "unauthenticated :user do"
        lines << "  root to: redirect(\"/users/sign_in\")"
        lines << "end"
      end

      unless authenticated_entries.empty?
        lines << "authenticated :user do"
        authenticated_entries.each { |entry| append_route_entry(lines, entry, indent: 2) }
        lines << "end"
      end

      public_entries.each { |entry| append_route_entry(lines, entry, indent: 0) }

      return "" if lines.empty?

      ([route_block_start_marker] + lines + [route_block_end_marker]).join("\n") + "\n"
    end

    def append_route_entry(lines, entry, indent:)
      type = entry["type"].to_s
      indent_padding = " " * indent

      case type
      when "root"
        line = "#{indent_padding}root to: #{quoted(entry.fetch('to'))}"
        line += ", as: :#{entry['as']}" if entry["as"]
        lines << line
      when "get"
        line = "#{indent_padding}get #{quoted(entry.fetch('path'))}, to: #{quoted(entry.fetch('to'))}"
        line += ", as: :#{entry['as']}" if entry["as"]
        lines << line
      when "resources"
        line = "#{indent_padding}resources :#{entry.fetch('name')}"
        options = []
        options << "only: #{symbol_array(entry['only'])}" if entry["only"]
        options << "controller: #{quoted(entry['controller'])}" if entry["controller"]
        line += ", #{options.join(', ')}" unless options.empty?

        nested = entry["nested"]
        if nested.is_a?(Array) && !nested.empty?
          lines << "#{line} do"
          nested.each { |child| append_route_entry(lines, child, indent: indent + 2) }
          lines << "#{indent_padding}end"
        else
          lines << line
        end
      else
        raise InvalidConfiguration, "Unsupported route entry type: #{type}"
      end
    end

    def ensure_controller_files!
      controller_specs.each do |controller_path, spec|
        file_path = File.join(workspace, "app/controllers", "#{controller_path}_controller.rb")
        if dry_run
          ui.info("Dry run: ensure controller #{file_path}")
          next
        end

        next if File.exist?(file_path)

        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, build_controller_content(controller_path, spec[:actions], authenticated: spec[:authenticated]))
      end
    end

    def ensure_policy_files!
      policy_names = recipe.authorization_policies
      return if policy_names.empty?

      policy_names.each do |policy_name|
        file_path = File.join(workspace, "app/policies", "#{policy_name}.rb")
        if dry_run
          ui.info("Dry run: ensure policy #{file_path}")
          next
        end

        next if File.exist?(file_path)

        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, build_policy_content(policy_name))
      end
    end

    def controller_specs
      @controller_specs ||= begin
        specs = Hash.new { |hash, key| hash[key] = { actions: Set.new, authenticated: false } }
        route_entries("authenticated").each { |entry| collect_route_controller_specs(entry, specs, authenticated: true) }
        route_entries("public").each { |entry| collect_route_controller_specs(entry, specs, authenticated: false) }
        specs
      end
    end

    def collect_route_controller_specs(entry, specs, authenticated:)
      type = entry["type"].to_s

      case type
      when "root", "get"
        controller_path, action = controller_and_action_from_to(entry.fetch("to"))
        add_controller_action(specs, controller_path, action, authenticated: authenticated)
      when "resources"
        controller_path = entry["controller"] || entry.fetch("name")
        actions = resource_actions(entry)
        actions.each { |action| add_controller_action(specs, controller_path, action, authenticated: authenticated) }

        nested = entry["nested"]
        nested.each { |child| collect_route_controller_specs(child, specs, authenticated: authenticated) } if nested.is_a?(Array)
      end
    end

    def add_controller_action(specs, controller_path, action, authenticated:)
      spec = specs[controller_path]
      spec[:actions] << action
      spec[:authenticated] ||= authenticated
    end

    def route_entries(scope)
      routes = recipe.routes
      entries = routes[scope]
      return [] unless entries.is_a?(Array)

      entries
    end

    def resource_actions(entry)
      only = entry["only"]
      return only.map(&:to_s) if only.is_a?(Array) && !only.empty?

      %w[index show create update destroy]
    end

    def controller_and_action_from_to(to)
      controller, action = to.split("#", 2)
      raise InvalidConfiguration, "Invalid route target format: #{to}" if controller.to_s.empty? || action.to_s.empty?

      [controller, action]
    end

    def build_controller_content(controller_path, actions, authenticated:)
      parts = controller_path.split("/")
      class_name = "#{camelize(parts.last)}Controller"
      modules = parts[0...-1].map { |part| camelize(part) }
      action_methods = actions.to_a.sort.map { |action| "  def #{action}\n  end\n" }.join("\n")
      auth_line = authenticated ? "  before_action :authenticate_user!\n\n" : ""

      if modules.empty?
        <<~RUBY
          # frozen_string_literal: true

          class #{class_name} < ApplicationController
          #{auth_line}#{action_methods}
          end
        RUBY
      else
        module_openings = modules.map { |mod| "module #{mod}" }.join("\n")
        module_closings = modules.map { "end" }.join("\n")
        indented_controller = <<~RUBY
          class #{class_name} < ApplicationController
          #{auth_line}#{action_methods}
          end
        RUBY
        indented_controller = indented_controller.lines.map { |line| line.strip.empty? ? line : "  #{line}" }.join

        <<~RUBY
          # frozen_string_literal: true

          #{module_openings}
          #{indented_controller}#{module_closings}
        RUBY
      end
    end

    def build_policy_content(policy_name)
      class_name = camelize(policy_name.sub(/_policy\z/, "")) + "Policy"

      <<~RUBY
        # frozen_string_literal: true

        class #{class_name} < ApplicationPolicy
          def index?
            user.present?
          end

          def show?
            user.present?
          end

          def create?
            user.present?
          end

          def new?
            create?
          end

          def update?
            user.present?
          end

          def edit?
            update?
          end

          def destroy?
            user.present?
          end
        end
      RUBY
    end

    def quoted(value)
      "\"#{value}\""
    end

    def symbol_array(values)
      symbols = values.map { |value| ":#{value}" }.join(", ")
      "[#{symbols}]"
    end

    def camelize(value)
      value.to_s.split("_").map(&:capitalize).join
    end
  end
end
