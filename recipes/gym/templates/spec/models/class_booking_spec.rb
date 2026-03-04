# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClassBooking, type: :model do
  it "prevents duplicate booking for the same member and class" do
    location = GymLocation.create!(name: "HQ", code: "hq", timezone: "UTC")
    session = ClassSession.create!(
      gym_location: location,
      title: "Yoga",
      instructor_name: "Coach",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 1.hour,
      capacity: 10,
      status: :scheduled
    )
    member = Member.create!(gym_location: location, first_name: "Ana", last_name: "Diaz", email: "ana@example.com")

    described_class.create!(class_session: session, member: member, status: :booked)
    duplicate = described_class.new(class_session: session, member: member, status: :booked)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:member_id]).to include("has already been taken")
  end
end
