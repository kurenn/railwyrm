# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Gym visits", type: :request do
  it "records a check-in" do
    user = create_authenticated_user(role: :staff)
    location = ensure_base_location!
    member = Member.create!(gym_location: location, first_name: "Ana", last_name: "Diaz", email: "ana@example.com")
    sign_in user

    post visits_path, params: { member_id: member.id }

    expect(response).to redirect_to(visits_path)
    expect(Visit.last.member).to eq(member)
  end
end
