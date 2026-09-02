# frozen_string_literal: true

require "spec_helper"
require "open3"

# Every other spec in this suite drives a fake shell, which can only prove that
# Railwyrm wrote the strings it meant to write. This one generates a real Rails
# app and makes it boot, which is the thing users actually depend on.
#
# Run with: RUN_E2E=1 bundle exec rspec spec/e2e
RSpec.describe "a generated Rails app", e2e: true do
  def capture!(*command, chdir:)
    output, status = Bundler.with_unbundled_env { Open3.capture2e(*command, chdir: chdir) }
    raise "#{command.join(' ')} failed in #{chdir}:\n#{output}" unless status.success?

    output
  end

  def available?(command)
    Bundler.with_unbundled_env { Open3.capture2e(command).last.success? }
  end

  before(:all) do
    # Deliberately raise rather than skip: if you asked for the e2e run, a
    # missing dependency is a failure, not a quietly green suite.
    raise "e2e needs the rails gem on PATH" unless available?("rails -v")
    raise "e2e needs a reachable PostgreSQL server" unless available?("pg_isready")
  end

  it "migrates the full devise stack and boots under its own test suite" do
    Dir.mktmpdir do |workspace|
      configuration = Railwyrm::Configuration.new(
        name: "e2e_app",
        workspace: workspace,
        devise_confirmable: true,
        devise_lockable: true,
        devise_trackable: true,
        verbose: true
      )

      Railwyrm::Generator.new(configuration, ui: Railwyrm::UI::Console.new(verbose: true)).run!
      app_path = configuration.app_path

      # Each optional module needs its own columns. Combining them used to
      # produce one migration, then two migrations sharing a version.
      schema = File.read(File.join(app_path, "db/schema.rb"))
      expect(schema).to include("confirmation_token")
      expect(schema).to include("unlock_token")
      expect(schema).to include("sign_in_count")

      # Generation is pinned, so the Gemfile should be right without a rewrite.
      expect(File.read(File.join(app_path, "Gemfile"))).to match(/gem "rails", "~> 8\.0\./)

      expect(File).to exist(File.join(app_path, ".github/workflows/ci.yml"))

      capture!("bin/rails", "runner", "User.new", chdir: app_path)

      FileUtils.mkdir_p(File.join(app_path, "spec/models"))
      File.write(
        File.join(app_path, "spec/models/user_spec.rb"),
        <<~SPEC
          require "rails_helper"

          RSpec.describe User do
            it "has the devise modules Railwyrm enabled" do
              expect(User.devise_modules).to include(:confirmable, :lockable, :trackable)
            end
          end
        SPEC
      )

      output = capture!("bundle", "exec", "rspec", chdir: app_path)
      expect(output).to match(/1 example, 0 failures/)
    end
  end
end
