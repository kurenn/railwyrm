# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::FeatureState do
  it "writes and reads tracked features manifest" do
    Dir.mktmpdir do |app_path|
      ui = Railwyrm::UI::Buffer.new
      state = described_class.new(app_path: app_path, ui: ui)

      state.replace!(%w[trackable magic_link])

      manifest_path = File.join(app_path, ".railwyrm/features.yml")
      expect(File).to exist(manifest_path)
      expect(state.tracked_features).to eq(%w[trackable magic_link])
    end
  end

  it "does not write manifest in dry-run mode" do
    Dir.mktmpdir do |app_path|
      ui = Railwyrm::UI::Buffer.new
      state = described_class.new(app_path: app_path, ui: ui, dry_run: true)

      state.mark_installed!(%w[trackable])

      manifest_path = File.join(app_path, ".railwyrm/features.yml")
      expect(File).not_to exist(manifest_path)
      expect(state.tracked_features).to eq([])
    end
  end
end
