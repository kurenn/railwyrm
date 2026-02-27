# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::Configuration do
  it "defaults sign_in_layout to card_combined" do
    config = described_class.new(name: "demo_app", workspace: "/tmp")

    expect(config.sign_in_layout).to eq("card_combined")
  end

  it "accepts each supported sign_in_layout" do
    described_class::SIGN_IN_LAYOUTS.each do |layout|
      config = described_class.new(name: "demo_app", workspace: "/tmp", sign_in_layout: layout)
      expect(config.sign_in_layout).to eq(layout)
    end
  end

  it "raises on unsupported sign_in_layout" do
    expect do
      described_class.new(name: "demo_app", workspace: "/tmp", sign_in_layout: "unknown")
    end.to raise_error(Railwyrm::InvalidConfiguration, /Sign-in layout/)
  end
end
