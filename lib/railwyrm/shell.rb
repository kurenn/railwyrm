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

    FAILURE_CONTEXT_LINES = 8

    def run!(*command, chdir: nil)
      raise ArgumentError, "Command cannot be empty" if command.empty?

      pretty_command = command.map { |part| Shellwords.escape(part.to_s) }.join(" ")
      @ui.command(pretty_command, chdir: chdir)
      return true if @dry_run

      with_unbundled_env do
        Open3.popen2e(*command, chdir: chdir) do |stdin, output, wait_thr|
          stdin.close

          head = []
          tail = []
          dropped = 0

          output.each_line do |line|
            stripped = line.rstrip
            next if stripped.empty?

            @ui.stream(stripped) if @verbose

            if head.length < FAILURE_CONTEXT_LINES
              head << stripped
            else
              tail << stripped
              if tail.length > FAILURE_CONTEXT_LINES
                tail.shift
                dropped += 1
              end
            end
          end

          status = wait_thr.value
          return true if status.success?

          raise CommandFailed, failure_message(pretty_command, status, head, tail, dropped)
        end
      end
    end

    private

    def failure_message(pretty_command, status, head, tail, dropped)
      message = "Command failed with status #{status.exitstatus}: #{pretty_command}"
      context = head
      context += ["... #{dropped} more line(s) ..."] if dropped.positive?
      context += tail
      return message if context.empty?

      [message, *context].join("\n")
    end

    def with_unbundled_env
      if defined?(Bundler)
        Bundler.with_unbundled_env { yield }
      else
        yield
      end
    end
  end
end
