# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ATS candidates", type: :request do
  it "allows recruiter to create a candidate" do
    user = create_authenticated_user
    ensure_department!
    sign_in user

    expect do
      post candidates_path, params: {
        candidate: {
          first_name: "Lily",
          last_name: "Rose",
          email: "lily.rose@example.test",
          location: "Remote",
          source: "referral"
        }
      }
    end.to change(Candidate, :count).by(1)

    expect(response).to redirect_to(candidate_path(Candidate.last))
  end
end
