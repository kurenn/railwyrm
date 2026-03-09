# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::FeatureRegistry do
  it "lists supported features" do
    expect(described_class.list).to include("confirmable", "lockable", "timeoutable", "trackable", "magic_link")
  end

  it "resolves dependencies for requested features" do
    resolved = described_class.resolve(["magic_link"])

    expect(resolved).to eq(%w[trackable magic_link])
  end

  it "raises for unknown features" do
    expect do
      described_class.resolve(["unknown_feature"])
    end.to raise_error(Railwyrm::InvalidConfiguration, /Unknown feature/) 
  end
end
