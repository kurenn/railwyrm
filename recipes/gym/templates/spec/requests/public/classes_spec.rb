# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public classes", type: :request do
  it "renders schedule page" do
    location = GymLocation.create!(name: "HQ", code: "hq", timezone: "UTC")
    ClassSession.create!(
      gym_location: location,
      title: "HIIT",
      instructor_name: "Coach",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 1.hour,
      capacity: 15,
      status: :scheduled
    )

    get schedule_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Class schedule")
    expect(response.body).to include("HIIT")
  end
end
