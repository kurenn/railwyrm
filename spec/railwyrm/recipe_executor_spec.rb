# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::RecipeExecutor do
  class RecipeExecutorFakeShell
    attr_reader :commands

    def initialize
      @commands = []
    end

    def run!(*command, chdir: nil)
      commands << { command: command, chdir: chdir }
      true
    end
  end

  def recipe_with_commands(commands)
    Railwyrm::Recipe.new(
      path: "/tmp/recipe.yml",
      data: {
        "id" => "ats",
        "name" => "Applicant Tracking System",
        "version" => "0.1.0",
        "scaffolding_plan" => { "commands" => commands }
      }
    )
  end

  it "produces a deterministic plan in recipe order" do
    recipe = recipe_with_commands(["echo first", "echo second"])
    executor = described_class.new(
      recipe,
      workspace: "/tmp",
      ui: Railwyrm::UI::Buffer.new,
      shell: RecipeExecutorFakeShell.new
    )

    plan = executor.plan

    expect(plan.map(&:index)).to eq([1, 2])
    expect(plan.map(&:command)).to eq(["echo first", "echo second"])
  end

  it "applies commands in the same order as the plan" do
    Dir.mktmpdir do |workspace|
      shell = RecipeExecutorFakeShell.new
      recipe = recipe_with_commands(["echo one", "echo two"])
      executor = described_class.new(
        recipe,
        workspace: workspace,
        ui: Railwyrm::UI::Buffer.new,
        shell: shell
      )

      executor.apply!

      executed = shell.commands.map { |entry| entry[:command].join(" ") }
      expect(executed).to eq(["echo one", "echo two"])
      expect(shell.commands.map { |entry| entry[:chdir] }).to all(eq(File.expand_path(workspace)))
    end
  end

  it "fails when workspace does not exist" do
    missing_workspace = File.join(Dir.tmpdir, "missing-workspace-#{Process.pid}")
    recipe = recipe_with_commands(["echo one"])
    executor = described_class.new(
      recipe,
      workspace: missing_workspace,
      ui: Railwyrm::UI::Buffer.new,
      shell: RecipeExecutorFakeShell.new
    )

    expect { executor.apply! }
      .to raise_error(Railwyrm::InvalidConfiguration, /Workspace does not exist/)
  end

  it "respects dry run mode via shell and avoids command side effects" do
    Dir.mktmpdir do |workspace|
      marker = File.join(workspace, "dry-run-marker.txt")
      recipe = recipe_with_commands(["touch #{marker}"])
      ui = Railwyrm::UI::Buffer.new
      shell = Railwyrm::Shell.new(ui: ui, dry_run: true, verbose: false)
      executor = described_class.new(recipe, workspace: workspace, ui: ui, shell: shell)

      executor.apply!

      expect(File).not_to exist(marker)
    end
  end
end
