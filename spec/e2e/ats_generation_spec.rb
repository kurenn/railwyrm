# frozen_string_literal: true

require "spec_helper"

require "open3"
require "timeout"

RSpec.describe "ATS e2e generation", :e2e do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:pg_host) { ENV.fetch("PGHOST", "127.0.0.1") }
  let(:pg_user) { ENV.fetch("PGUSER", "postgres") }
  let(:pg_password) { ENV.fetch("PGPASSWORD", "postgres") }
  let(:e2e_timeout_seconds) { 1_200 } # 20 minutes

  def run_command(*command, chdir:, env: {})
    full_env = {
      "PGHOST" => pg_host,
      "PGUSER" => pg_user,
      "PGPASSWORD" => pg_password
    }.merge(env)

    output = +""
    status = nil

    Timeout.timeout(e2e_timeout_seconds) do
      output, status = Open3.capture2e(full_env, *command, chdir: chdir)
    end

    [output, status]
  end

  def command_available?(binary)
    _, status = Open3.capture2e("which", binary)
    status.success?
  end

  def postgres_available?
    return false unless command_available?("pg_isready")

    _output, status = Open3.capture2e(
      { "PGHOST" => pg_host, "PGUSER" => pg_user, "PGPASSWORD" => pg_password },
      "pg_isready",
      "-h",
      pg_host,
      "-U",
      pg_user
    )
    status.success?
  end

  def rails_new_available?
    _output, status = Open3.capture2e("rails", "new", "--help")
    status.success?
  end

  it "generates a new app with --recipe ats and passes core rails checks" do
    skip "Set RUN_E2E=1 to run e2e specs" unless ENV["RUN_E2E"] == "1"
    skip "rails command is unavailable for e2e run" unless command_available?("rails")
    skip "rails new is unavailable for e2e run" unless rails_new_available?
    skip "postgres is unavailable for e2e run" unless postgres_available?

    Dir.mktmpdir("railwyrm-ats-e2e-") do |workspace|
      app_name = "ats_e2e_app"
      app_path = File.join(workspace, app_name)

      output, status = run_command(
        "bundle",
        "exec",
        "ruby",
        "exe/railwyrm",
        "new",
        app_name,
        "--interactive=false",
        "--path",
        workspace,
        "--recipe",
        "ats",
        "--no-banner",
        chdir: repo_root
      )

      expect(status.success?).to be(true), <<~MSG
        expected ATS generation to succeed, but it failed.
        Output:
        #{output}
      MSG

      expect(Dir).to exist(app_path)

      expected_paths = [
        "config/routes.rb",
        "app/controllers/ats/dashboard_controller.rb",
        "app/controllers/ats/reports_controller.rb",
        "app/controllers/public/careers_controller.rb",
        "app/policies/job_posting_policy.rb",
        "app/views/ats/dashboard/show.html.erb",
        "app/views/ats/job_postings/index.html.erb",
        "app/views/public/careers/index.html.erb",
        "db/seeds/ats.seeds.rb"
      ]
      expected_paths.each do |relative_path|
        expect(File).to exist(File.join(app_path, relative_path)), "Missing generated path: #{relative_path}"
      end

      routes_content = File.read(File.join(app_path, "config/routes.rb"))
      expect(routes_content).to include("# BEGIN railwyrm:recipe:ats")
      expect(routes_content).to include("authenticated :user do")
      expect(routes_content).to include("resources :careers")

      rspec_output, rspec_status = run_command("bundle", "exec", "rspec", chdir: app_path)
      expect(rspec_status.success?).to be(true), "bundle exec rspec failed:\n#{rspec_output}"

      routes_output, routes_status = run_command("bin/rails", "routes", chdir: app_path)
      expect(routes_status.success?).to be(true), "bin/rails routes failed:\n#{routes_output}"

      zeitwerk_output, zeitwerk_status = run_command("bin/rails", "zeitwerk:check", chdir: app_path)
      expect(zeitwerk_status.success?).to be(true), "bin/rails zeitwerk:check failed:\n#{zeitwerk_output}"
    end
  end
end
