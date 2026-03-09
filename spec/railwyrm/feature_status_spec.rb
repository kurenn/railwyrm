# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::FeatureStatus do
  it "reports installed, tracked-only, and detected-only features" do
    Dir.mktmpdir do |app_path|
      File.write(File.join(app_path, "Gemfile"), "source \"https://rubygems.org\"\n")

      FileUtils.mkdir_p(File.join(app_path, "app/models"))
      File.write(
        File.join(app_path, "app/models/user.rb"),
        <<~RUBY
          class User < ApplicationRecord
            devise :database_authenticatable, :registerable, :trackable
          end
        RUBY
      )

      state = Railwyrm::FeatureState.new(app_path: app_path, ui: Railwyrm::UI::Buffer.new)
      state.replace!(%w[trackable confirmable])

      snapshot = described_class.new(app_path: app_path).snapshot

      expect(snapshot.fetch(:installed)).to eq(["trackable"])
      expect(snapshot.fetch(:tracked_only)).to eq(["confirmable"])
      expect(snapshot.fetch(:detected_only)).to eq([])
    end
  end

  it "raises when app path does not exist" do
    status = described_class.new(app_path: "/tmp/missing-app-#{Process.pid}")

    expect do
      status.snapshot
    end.to raise_error(Railwyrm::InvalidConfiguration, /Rails app path not found/)
  end
end
