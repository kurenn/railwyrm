# frozen_string_literal: true

require "rails_helper"

RSpec.describe GymLocation, type: :model do
  it "normalizes code" do
    location = described_class.create!(name: "Downtown", code: "Downtown HQ", timezone: "UTC")

    expect(location.code).to eq("downtown_hq")
  end
end
