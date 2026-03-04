# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Gym members", type: :request do
  it "allows staff to create a member" do
    user = create_authenticated_user(role: :staff)
    location = ensure_base_location!
    sign_in user

    post members_path, params: {
      member: {
        first_name: "Mila",
        last_name: "Stone",
        email: "mila.stone@example.com",
        phone: "+1-555-0000",
        joined_on: Date.current,
        status: :active
      }
    }

    expect(response).to redirect_to(member_path(Member.last))
    expect(Member.last.gym_location).to eq(location)
  end
end
