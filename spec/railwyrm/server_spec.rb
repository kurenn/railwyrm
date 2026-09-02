# frozen_string_literal: true

require "spec_helper"
require "json"
require "rack/mock_request"

RSpec.describe Railwyrm::Server do
  around do |example|
    Dir.mktmpdir { |root| @workspace = root; example.run }
  end

  attr_reader :workspace

  def real_workspace
    File.realpath(workspace)
  end

  # Stub the worker so no example ever shells out to a real `rails new`.
  def build_server
    described_class.new(host: "127.0.0.1", port: 4567, workspace: workspace).tap do |server|
      allow(server).to receive(:run_job)
    end
  end

  def post_json(server, path, payload)
    env = Rack::MockRequest.env_for(
      path,
      method: "POST",
      input: JSON.generate(payload),
      "CONTENT_TYPE" => "application/json"
    )
    status, _headers, body = server.rack_app.call(env)
    [status, JSON.parse(body.each.to_a.join)]
  end

  it "reads the app name from a JSON request body" do
    status, payload = post_json(build_server, "/api/apps", "name" => "forged_app")

    expect(status).to eq(202)
    expect(payload.fetch("app_name")).to eq("forged_app")
    expect(payload.fetch("app_path")).to eq(File.join(real_workspace, "forged_app"))
  end

  it "rejects a JSON request whose workspace escapes the root" do
    status, payload = post_json(build_server, "/api/apps", "name" => "forged_app", "workspace" => "/etc")

    expect(status).to eq(422)
    expect(payload.fetch("error")).to match(/Workspace must be inside/)
  end

  it "generates inside the configured workspace by default" do
    job = build_server.enqueue("name" => "forged_app")

    expect(job.fetch(:app_path)).to eq(File.join(real_workspace, "forged_app"))
  end

  it "resolves a relative workspace against the configured root" do
    job = build_server.enqueue("name" => "forged_app", "workspace" => "nested/projects")

    expect(job.fetch(:app_path)).to eq(File.join(real_workspace, "nested/projects/forged_app"))
  end

  it "rejects a workspace outside the configured root" do
    expect do
      build_server.enqueue("name" => "forged_app", "workspace" => "/etc")
    end.to raise_error(Railwyrm::InvalidConfiguration, /Workspace must be inside/)
  end

  it "rejects traversal out of the configured root" do
    expect do
      build_server.enqueue("name" => "forged_app", "workspace" => "../../escape")
    end.to raise_error(Railwyrm::InvalidConfiguration, /Workspace must be inside/)
  end

  it "rejects a symlink inside the root that points outside it" do
    Dir.mktmpdir do |outside|
      File.symlink(outside, File.join(workspace, "escape_hatch"))

      expect do
        build_server.enqueue("name" => "forged_app", "workspace" => "escape_hatch")
      end.to raise_error(Railwyrm::InvalidConfiguration, /Workspace must be inside/)
    end
  end

  it "rejects a missing app name without raising KeyError" do
    expect do
      build_server.enqueue({})
    end.to raise_error(Railwyrm::InvalidConfiguration, /App name is required/)
  end
end
