# frozen_string_literal: true

require "fileutils"
require "shellwords"

module Railwyrm
  class RecipeExecutor
    Step = Struct.new(:index, :command, keyword_init: true)

    def initialize(recipe, workspace:, ui:, shell:, dry_run: false)
      @recipe = recipe
      @workspace = File.expand_path(workspace)
      @ui = ui
      @shell = shell
      @dry_run = dry_run
    end

    def plan
      recipe.scaffolding_commands.each_with_index.map do |command, index|
        Step.new(index: index + 1, command: command)
      end
    end

    def apply!
      ensure_workspace!
      steps = plan

      ui.headline("Applying recipe #{recipe.id}@#{recipe.version} in #{workspace}")
      steps.each do |step|
        ui.step("Recipe step #{step.index}/#{steps.length}") do
          shell.run!(*Shellwords.split(step.command), chdir: workspace)
        end
      end

      ui.step("Apply recipe UI overlays") do
        apply_ui_overlays!
      end

      ui.step("Install recipe seeds") do
        install_seed_data!
      end

      ui.success("Recipe apply complete for #{recipe.id}")
      true
    end

    private

    attr_reader :recipe, :workspace, :ui, :shell, :dry_run

    def ensure_workspace!
      raise InvalidConfiguration, "Workspace does not exist: #{workspace}" unless Dir.exist?(workspace)
    end

    def apply_ui_overlays!
      recipe.ui_overlay_copies.each do |copy|
        source = recipe.resolve_reference_path(copy.fetch("from"))
        destination_root = File.join(workspace, copy.fetch("to"))
        raise InvalidConfiguration, "UI overlay source does not exist: #{source}" unless Dir.exist?(source)

        if dry_run
          ui.info("Dry run: copy #{source} -> #{destination_root}")
          next
        end

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
  end
end
