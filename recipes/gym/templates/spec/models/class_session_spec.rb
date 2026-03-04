# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClassSession, type: :model do
  it "calculates spots_left from bookings" do
    location = GymLocation.create!(name: "HQ", code: "hq", timezone: "UTC")
    session = described_class.create!(
      gym_location: location,
      title: "HIIT",
      instructor_name: "Coach",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 1.hour,
      capacity: 2,
      status: :scheduled
    )

    member = Member.create!(gym_location: location, first_name: "A", last_name: "B", email: "ab@example.com")
    ClassBooking.create!(class_session: session, member: member, status: :booked)

    expect(session.spots_left).to eq(1)
  end
end
