# frozen_string_literal: true

require "rails_helper"

RSpec.describe MembershipPlan, type: :model do
  it "validates non-negative pricing" do
    location = GymLocation.create!(name: "HQ", code: "hq", timezone: "UTC")
    plan = described_class.new(gym_location: location, name: "Pro", billing_cycle: "monthly", price_cents: -1)

    expect(plan).not_to be_valid
    expect(plan.errors[:price_cents]).to include("must be greater than or equal to 0")
  end
end
