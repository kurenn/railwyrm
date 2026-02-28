# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require "railwyrm"

RSpec.configure do |config|
  config.filter_run_excluding e2e: true unless ENV["RUN_E2E"] == "1"
end
