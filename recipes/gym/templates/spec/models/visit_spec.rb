# frozen_string_literal: true

require "rails_helper"

RSpec.describe Visit, type: :model do
  it "requires checked_out_at after checked_in_at" do
    location = GymLocation.create!(name: "HQ", code: "hq", timezone: "UTC")
    member = Member.create!(gym_location: location, first_name: "Ana", last_name: "Diaz", email: "ana@example.com")

    visit = described_class.new(member: member, gym_location: location, checked_in_at: Time.current, checked_out_at: 1.hour.ago)

    expect(visit).not_to be_valid
    expect(visit.errors[:checked_out_at]).to include("must be after checked_in_at")
  end
end
