# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::UIProfileCatalog do
  it "discovers shared ui profiles in deterministic order" do
    catalog = described_class.new(repository_root: File.expand_path("../..", __dir__))

    expect(catalog.list).to include("dashboard_05")
  end

  it "returns standard overlay copies for a profile" do
    catalog = described_class.new(repository_root: "/tmp/demo-repo")

    expect(catalog.overlay_copies_for("dashboard_05")).to eq(
      [
        {
          "from" => "recipes/_shared/ui_profiles/dashboard_05/views",
          "to" => "app/views"
        },
        {
          "from" => "recipes/_shared/ui_profiles/dashboard_05/components",
          "to" => "app/components"
        }
      ]
    )
  end

  it "reports missing overlay paths for incomplete profile assets" do
    Dir.mktmpdir do |dir|
      profile_root = File.join(dir, "recipes", "_shared", "ui_profiles", "dashboard_05")
      FileUtils.mkdir_p(File.join(profile_root, "views"))
      catalog = described_class.new(repository_root: dir)

      missing_paths = catalog.missing_overlay_paths_for("dashboard_05")
      expect(missing_paths).to include("recipes/_shared/ui_profiles/dashboard_05/components")
      expect(missing_paths).not_to include("recipes/_shared/ui_profiles/dashboard_05/views")
    end
  end
end
