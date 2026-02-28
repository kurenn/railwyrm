# frozen_string_literal: true

require "shellwords"

module Railwyrm
  class RecipeExecutor
    Step = Struct.new(:index, :command, keyword_init: true)

    def initialize(recipe, workspace:, ui:, shell:)
      @recipe = recipe
      @workspace = File.expand_path(workspace)
      @ui = ui
      @shell = shell
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
      ui.success("Recipe apply complete for #{recipe.id}")
      true
    end

    private

    attr_reader :recipe, :workspace, :ui, :shell

    def ensure_workspace!
      raise InvalidConfiguration, "Workspace does not exist: #{workspace}" unless Dir.exist?(workspace)
    end
  end
end
