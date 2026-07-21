# frozen_string_literal: true

require "spec_helper"

RSpec.describe "railwyrm.gemspec" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:gemspec) { Gem::Specification.load(File.join(root, "railwyrm.gemspec")) }

  # `railwyrm new` reads templates off disk at runtime. A file that lives under
  # lib/ but isn't listed in spec.files works fine from a git checkout and then
  # blows up for anyone who installed the gem, which is exactly how the CI
  # workflow template went missing in 0.2.0.
  it "packages every template file under lib/, not just Ruby sources" do
    on_disk = Dir.glob("lib/**/*", base: root).reject do |path|
      File.directory?(File.join(root, path))
    end

    missing = on_disk - gemspec.files

    expect(missing).to be_empty,
      "these files live under lib/ but are not in spec.files, so they will be " \
      "absent from the built gem:\n  #{missing.join("\n  ")}"
  end

  it "packages the CI workflow template the generator copies into new apps" do
    expect(gemspec.files).to include("lib/railwyrm/templates/ci/github_actions_ci.yml")
  end

  it "packages the executable" do
    expect(gemspec.files).to include("exe/railwyrm")
  end
end
