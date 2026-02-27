# frozen_string_literal: true

require "time"

module Railwyrm
  module UI
    class Banner
      MASCOT = <<~ASCII
                     / \  //\\
      |\\___/|      /   \//  .\\
      /0  0  \\__  /    //  | \\ \\
     /     /  \\/_/    //   |  \\  \\
     @_^_@'/   \\/_   //    |   \\   \\
     //_^_/     \\/_ //     |    \\    \\
  ( //) |        \\///      |     \\     \\
( / /) _|_ /   )  //       |      \\     _\\
( // /) '/,_ _ _/  ( ; -.   |    _ _\\.-~        .-~~~^-.
(( / / )) ,-{        _      `-.|.-~-.           .~         `.
(( // / ))  '/\\      /                 ~-. _ .-~      .-~^-.  \\
(( /// ))      `.   {            }                   /      \\  \\
 (( / ))     .----~-.\\        \\-'                 .~         \\  `. \\^-.
            ///.----..>        \\             _ -~             `.  ^-`  ^-_ 
              ///-._ _ _ _ _ _ _}^ - - - - ~                     ~--,   .-~
                                                                     /.-'
ASCII

      def render(io: $stdout)
        pastel = Pastel.new(enabled: io.tty?)
        font = TTY::Font.new(:doom)
        logo = font.write("Railwyrm")

        palette = %i[bright_red bright_magenta bright_yellow bright_cyan]
        colored_logo = logo.lines.each_with_index.map do |line, index|
          color = palette[index % palette.length]
          pastel.decorate(line.chomp, color, :bold)
        end.join("\n")

        io.puts colored_logo
        io.puts pastel.decorate("🐉 Emberclaw the forge-dragon is ready.", :bright_red, :bold)
        io.puts pastel.decorate("⚔️  Tailwind + PG + RSpec + Devise + ActiveStorage + ActionText + Untitled UI + Claude-on-Rails", :bright_black)
        io.puts pastel.decorate(MASCOT, :bright_yellow)
      end
    end

    class Console
      def initialize(verbose: false, io: $stdout)
        @io = io
        @pastel = Pastel.new(enabled: io.tty?)
        @verbose = verbose
      end

      def headline(message)
        @io.puts @pastel.decorate("\n#{message}", :bright_magenta, :bold)
      end

      def info(message)
        @io.puts @pastel.decorate("ℹ #{message}", :bright_blue)
      end

      def success(message)
        @io.puts @pastel.decorate("✅ #{message}", :green)
      end

      def warn(message)
        @io.puts @pastel.decorate("⚠ #{message}", :yellow)
      end

      def error(message)
        @io.puts @pastel.decorate("❌ #{message}", :red, :bold)
      end

      def command(command, chdir: nil)
        location = chdir ? " (in #{chdir})" : ""
        @io.puts @pastel.decorate("$ #{command}#{location}", :cyan)
      end

      def stream(message)
        return unless @verbose

        @io.puts @pastel.decorate("  #{message}", :bright_black)
      end

      def step(title)
        spinner = TTY::Spinner.new("[:spinner] #{title}", format: :dots)
        spinner.auto_spin
        result = yield
        spinner.success(@pastel.decorate("done", :green))
        result
      rescue StandardError
        spinner.error(@pastel.decorate("failed", :red))
        raise
      end

      def render_sign_in_layout_gallery
        SignInLayoutGallery.new(pastel: @pastel).render(io: @io)
      end
    end

    class Buffer
      attr_reader :logs

      def initialize(logs: [])
        @logs = logs
      end

      def headline(message)
        push("headline", message)
      end

      def info(message)
        push("info", message)
      end

      def success(message)
        push("success", message)
      end

      def warn(message)
        push("warn", message)
      end

      def error(message)
        push("error", message)
      end

      def command(command, chdir: nil)
        location = chdir ? " (in #{chdir})" : ""
        push("command", "$ #{command}#{location}")
      end

      def stream(message)
        push("stream", message)
      end

      def step(title)
        push("step", "#{title} ...")
        result = yield
        push("step", "#{title} complete")
        result
      rescue StandardError => e
        push("step", "#{title} failed: #{e.message}")
        raise
      end

      private

      def push(level, message)
        logs << {
          at: Time.now.utc.iso8601,
          level: level,
          message: message.to_s
        }
      end
    end

    class SignInLayoutGallery
      def initialize(pastel: Pastel.new)
        @pastel = pastel
      end

      def render(io: $stdout)
        io.puts @pastel.decorate("🎨 Choose your Devise sign-in look", :bright_cyan, :bold)
        io.puts @pastel.decorate("Each option generates app/views/devise/sessions/new.html.erb with Untitled UI components.", :bright_black)
        io.puts
        io.puts layout_card(
          key: "simple_minimal",
          title: "Simple Minimal",
          subtitle: "clean / centered / fast",
          accent: :bright_magenta,
          lines: [
            "┌────────────────────────────────────┐",
            "│  Welcome back                      │",
            "│  [ Email ]                         │",
            "│  [ Password ]                      │",
            "│  [ Sign in ]                       │",
            "└────────────────────────────────────┘"
          ]
        )
        io.puts
        io.puts layout_card(
          key: "card_combined",
          title: "Card Combined",
          subtitle: "balanced / polished / default",
          accent: :bright_yellow,
          lines: [
            "┌──────────── Auth Card ─────────────┐",
            "│ Email                              │",
            "│ Password            Forgot password│",
            "│ ☐ Remember me      [ Sign in ]     │",
            "└────────────────────────────────────┘"
          ]
        )
        io.puts
        io.puts layout_card(
          key: "split_mockup_quote",
          title: "Split Mockup Quote",
          subtitle: "marketing / testimonial / visual",
          accent: :bright_red,
          lines: [
            "┌──────── Form ───────┬─ Quote Panel ─┐",
            "│ [ Email ]           │ \"Teams ship   │",
            "│ [ Password ]        │  faster with  │",
            "│ [ Sign in ]         │  our stack.\"  │",
            "└─────────────────────┴───────────────┘"
          ]
        )
        io.puts
      end

      private

      def layout_card(key:, title:, subtitle:, accent:, lines:)
        header = @pastel.decorate("• #{key}", accent, :bold)
        name = @pastel.decorate(title, :white, :bold)
        sub = @pastel.decorate(subtitle, :bright_black)
        preview = lines.map { |line| @pastel.decorate(line, accent) }.join("\n")
        "#{header}  #{name}  #{sub}\n#{preview}"
      end
    end
  end
end
