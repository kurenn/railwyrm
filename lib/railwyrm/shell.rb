# frozen_string_literal: true

require "open3"
require "shellwords"

module Railwyrm
  class Shell
    def initialize(ui:, dry_run: false, verbose: false)
      @ui = ui
      @dry_run = dry_run
      @verbose = verbose
    end

    def run!(*command, chdir: nil)
      raise ArgumentError, "Command cannot be empty" if command.empty?

      pretty_command = command.map { |part| Shellwords.escape(part.to_s) }.join(" ")
      @ui.command(pretty_command, chdir: chdir)
      return true if @dry_run

      Open3.popen2e(*command, chdir: chdir) do |_stdin, output, wait_thr|
        output.each_line do |line|
          next unless @verbose

          stripped = line.rstrip
          @ui.stream(stripped) unless stripped.empty?
        end

        status = wait_thr.value
        return true if status.success?

        raise CommandFailed, "Command failed with status #{status.exitstatus}: #{pretty_command}"
      end
    end
  end
end
