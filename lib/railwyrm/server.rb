# frozen_string_literal: true

require "json"
require "securerandom"
require "time"
require "sinatra/base"

module Railwyrm
  class Server
    attr_reader :host, :port, :workspace

    def initialize(host:, port:, workspace:)
      @host = host
      @port = port
      @workspace = File.expand_path(workspace)
      @jobs = {}
      @mutex = Mutex.new
    end

    def start!
      app = rack_app
      app.run!
    end

    def rack_app
      server = self

      Class.new(Sinatra::Base) do
        set :server, :puma
        set :bind, server.host
        set :port, server.port
        set :show_exceptions, false

        before do
          headers "Access-Control-Allow-Origin" => "*"
        end

        options "*" do
          headers "Access-Control-Allow-Methods" => "GET,POST,OPTIONS"
          headers "Access-Control-Allow-Headers" => "Content-Type"
          200
        end

        get "/" do
          content_type :html
          server.dashboard_html
        end

        get "/health" do
          content_type :json
          JSON.generate(status: "ok", workspace: server.workspace)
        end

        post "/api/apps" do
          payload = parse_payload
          job = server.enqueue(payload)
          halt_json(202, job)
        rescue InvalidConfiguration => e
          halt_json(422, error: e.message)
        end

        get "/api/jobs/:id" do
          job = server.find_job(params[:id])
          halt_json(404, error: "Job not found") unless job

          halt_json(200, job)
        end

        error StandardError do
          halt_json(500, error: env["sinatra.error"].message)
        end

        helpers do
          def parse_payload
            if request.media_type == "application/json"
              raw = request.body.read
              return {} if raw.nil? || raw.empty?

              JSON.parse(raw)
            end

            params
          rescue JSON::ParserError
            halt_json(400, error: "Invalid JSON payload")
          end

          def halt_json(code, payload)
            content_type :json
            halt code, JSON.generate(payload)
          end
        end
      end
    end

    def enqueue(payload)
      name = payload.fetch("name")
      config = Configuration.new(
        name: name,
        workspace: payload["workspace"] || workspace,
        devise_user_model: payload["devise_user_model"] || "User",
        sign_in_layout: payload["sign_in_layout"] || "card_combined",
        install_devise_user: !truthy?(payload["skip_devise_user"]),
        dry_run: truthy?(payload["dry_run"]),
        verbose: true
      )

      job_id = SecureRandom.uuid
      job = {
        id: job_id,
        status: "queued",
        app_name: config.name,
        app_path: config.app_path,
        created_at: Time.now.utc.iso8601,
        logs: []
      }

      @mutex.synchronize { @jobs[job_id] = job }

      Thread.new do
        run_job(job_id, config)
      end

      job
    end

    def find_job(job_id)
      @mutex.synchronize do
        job = @jobs[job_id]
        job ? Marshal.load(Marshal.dump(job)) : nil
      end
    end

    def dashboard_html
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
          <title>Railwyrm Web Forge</title>
          <style>
            :root {
              --bg: #0f172a;
              --card: #111827;
              --accent: #ef4444;
              --accent-2: #f59e0b;
              --text: #f9fafb;
              --muted: #9ca3af;
            }
            body {
              margin: 0;
              font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif;
              background: radial-gradient(circle at 20% 20%, #1f2937, var(--bg));
              color: var(--text);
              min-height: 100vh;
              padding: 2rem;
            }
            .card {
              max-width: 900px;
              margin: 0 auto;
              background: linear-gradient(145deg, rgba(17,24,39,0.95), rgba(31,41,55,0.9));
              border: 1px solid rgba(255,255,255,0.1);
              border-radius: 16px;
              padding: 1.5rem;
              box-shadow: 0 30px 60px rgba(0,0,0,0.35);
            }
            h1 { margin-top: 0; font-size: 2rem; }
            p { color: var(--muted); }
            label { display: block; margin: 0.8rem 0 0.25rem; }
            input {
              width: 100%;
              box-sizing: border-box;
              padding: 0.7rem 0.9rem;
              border-radius: 10px;
              border: 1px solid rgba(255,255,255,0.15);
              background: rgba(17,24,39,0.8);
              color: var(--text);
            }
            .layout-grid {
              margin-top: 0.6rem;
              display: grid;
              gap: 0.75rem;
              grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            }
            .layout-card {
              border: 1px solid rgba(255,255,255,0.16);
              border-radius: 12px;
              padding: 0.7rem;
              background: rgba(2, 6, 23, 0.55);
              cursor: pointer;
            }
            .layout-card input[type="radio"] {
              width: auto;
              margin-right: 0.4rem;
              accent-color: #f59e0b;
            }
            .layout-card:hover {
              border-color: rgba(245,158,11,0.65);
            }
            .layout-title {
              display: flex;
              align-items: center;
              font-weight: 700;
              margin-bottom: 0.45rem;
            }
            .layout-wireframe {
              border: 1px solid rgba(255,255,255,0.15);
              border-radius: 8px;
              padding: 0.45rem;
              font-size: 0.75rem;
              color: #d1d5db;
              background: rgba(17,24,39,0.8);
              white-space: pre-line;
            }
            button {
              margin-top: 1rem;
              background: linear-gradient(90deg, var(--accent), var(--accent-2));
              color: #0b1020;
              font-weight: 700;
              border: none;
              border-radius: 10px;
              padding: 0.75rem 1rem;
              cursor: pointer;
            }
            pre {
              margin-top: 1rem;
              background: #020617;
              border: 1px solid rgba(255,255,255,0.08);
              border-radius: 10px;
              padding: 0.75rem;
              min-height: 220px;
              overflow: auto;
              white-space: pre-wrap;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>🐉 Railwyrm Web Forge</h1>
            <p>Kickstart Rails apps from your browser using the same defaults as the CLI.</p>
            <form id="forge-form">
              <label for="name">App name (snake_case)</label>
              <input id="name" name="name" value="my_awesome_app" required />
              <label for="workspace">Workspace path</label>
              <input id="workspace" name="workspace" value="#{workspace}" required />
              <label for="devise_user_model">Devise model name</label>
              <input id="devise_user_model" name="devise_user_model" value="User" />

              <label>Sign-in layout</label>
              <div class="layout-grid">
                <label class="layout-card">
                  <div class="layout-title"><input type="radio" name="sign_in_layout" value="simple_minimal">Simple Minimal</div>
                  <div class="layout-wireframe">Welcome back
[ Email ]
[ Password ]
[ Sign in ]</div>
                </label>
                <label class="layout-card">
                  <div class="layout-title"><input type="radio" name="sign_in_layout" value="card_combined" checked>Card Combined</div>
                  <div class="layout-wireframe">┌ Auth Card ┐
Email
Password     Forgot password
☐ Remember   [ Sign in ]</div>
                </label>
                <label class="layout-card">
                  <div class="layout-title"><input type="radio" name="sign_in_layout" value="split_mockup_quote">Split Mockup Quote</div>
                  <div class="layout-wireframe">Form | Quote Panel
[ Email ]   "Teams ship faster"
[ Password ]</div>
                </label>
              </div>

              <button type="submit">Forge New App</button>
            </form>
            <pre id="logs">Awaiting command...</pre>
          </div>
          <script>
            const form = document.getElementById("forge-form");
            const logs = document.getElementById("logs");

            function write(message) {
              logs.textContent = message;
            }

            form.addEventListener("submit", async (event) => {
              event.preventDefault();
              const payload = {
                name: document.getElementById("name").value,
                workspace: document.getElementById("workspace").value,
                devise_user_model: document.getElementById("devise_user_model").value,
                sign_in_layout: document.querySelector("input[name='sign_in_layout']:checked")?.value || "card_combined"
              };

              write("Starting forge job...\n");
              const createResponse = await fetch("/api/apps", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(payload)
              });

              const createData = await createResponse.json();
              if (!createResponse.ok) {
                write(`Error: ${createData.error}`);
                return;
              }

              const jobId = createData.id;
              const poll = async () => {
                const jobResponse = await fetch(`/api/jobs/${jobId}`);
                const jobData = await jobResponse.json();

                const lines = [
                  `Status: ${jobData.status}`,
                  `App Path: ${jobData.app_path}`,
                  "",
                  ...jobData.logs.map((log) => `[${log.at}] ${log.level.toUpperCase()} ${log.message}`)
                ];

                if (jobData.error) lines.push("", `Error: ${jobData.error}`);

                write(lines.join("\n"));

                if (["queued", "running"].includes(jobData.status)) {
                  setTimeout(poll, 1500);
                }
              };

              poll();
            });
          </script>
        </body>
        </html>
      HTML
    end

    private

    def run_job(job_id, config)
      with_job(job_id) do |job|
        job[:status] = "running"
        job[:started_at] = Time.now.utc.iso8601
      end

      logs = []
      ui = UI::Buffer.new(logs: logs)

      begin
        Generator.new(config, ui: ui).run!
        with_job(job_id) do |job|
          job[:status] = "completed"
          job[:finished_at] = Time.now.utc.iso8601
          job[:logs] = logs
        end
      rescue StandardError => e
        ui.error(e.message)
        with_job(job_id) do |job|
          job[:status] = "failed"
          job[:finished_at] = Time.now.utc.iso8601
          job[:error] = e.message
          job[:logs] = logs
        end
      end
    end

    def with_job(job_id)
      @mutex.synchronize do
        job = @jobs.fetch(job_id)
        yield job
      end
    end

    def truthy?(value)
      value == true || value.to_s.downcase == "true"
    end
  end
end
