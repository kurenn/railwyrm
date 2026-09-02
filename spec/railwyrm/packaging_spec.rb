# frozen_string_literal: true

require "spec_helper"

RSpec.describe "gem packaging" do
  it "ships every generator template in the built gem" do
    gemspec = Gem::Specification.load(File.expand_path("../../railwyrm.gemspec", __dir__))
    templates = Dir.glob("lib/railwyrm/templates/**/*").select { |path| File.file?(path) }

    expect(templates).not_to be_empty
    expect(gemspec.files).to include(*templates)
  end
end
