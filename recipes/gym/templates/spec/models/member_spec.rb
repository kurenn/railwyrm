# frozen_string_literal: true

require "rails_helper"

RSpec.describe Member, type: :model do
  it "normalizes email and exposes full_name" do
    location = GymLocation.create!(name: "HQ", code: "hq", timezone: "UTC")
    member = described_class.create!(gym_location: location, first_name: "Mila", last_name: "Stone", email: "MILA@EXAMPLE.COM")

    expect(member.email).to eq("mila@example.com")
    expect(member.full_name).to eq("Mila Stone")
  end

  it "enforces unique email per location" do
    location = GymLocation.create!(name: "HQ", code: "hq", timezone: "UTC")
    described_class.create!(gym_location: location, first_name: "Ana", last_name: "One", email: "ana@example.com")

    duplicate = described_class.new(gym_location: location, first_name: "Ana", last_name: "Two", email: "ana@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end
end
