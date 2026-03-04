# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public memberships", type: :request do
  it "creates a lead member request" do
    location = ensure_base_location!
    plan = ensure_plan!(location)

    post memberships_path, params: {
      member: {
        first_name: "Nora",
        last_name: "Miles",
        email: "nora@example.com",
        phone: "+1-555-1234"
      },
      membership_plan_id: plan.id
    }

    expect(response).to redirect_to(schedule_path)
    expect(Member.find_by(email: "nora@example.com")).to be_present
  end
end
