# frozen_string_literal: true

require_relative "lib/railwyrm"

server = Railwyrm::Server.new(
  host: ENV.fetch("RAILWYRM_HOST", "127.0.0.1"),
  port: ENV.fetch("RAILWYRM_PORT", "4567").to_i,
  workspace: ENV.fetch("RAILWYRM_WORKSPACE", Dir.pwd)
)

run server.rack_app
