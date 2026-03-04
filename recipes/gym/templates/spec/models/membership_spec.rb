# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership, type: :model do
  it "validates ends_on is not before starts_on" do
    location = GymLocation.create!(name: "HQ", code: "hq", timezone: "UTC")
    plan = MembershipPlan.create!(gym_location: location, name: "Pro", billing_cycle: "monthly", price_cents: 5000, active: true)
    member = Member.create!(gym_location: location, first_name: "Mila", last_name: "Stone", email: "mila@example.com")

    membership = described_class.new(
      member: member,
      membership_plan: plan,
      starts_on: Date.current,
      ends_on: Date.yesterday
    )

    expect(membership).not_to be_valid
    expect(membership.errors[:ends_on]).to include("must be on or after starts_on")
  end
end
