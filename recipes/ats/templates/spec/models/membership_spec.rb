# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership, type: :model do
  it "stores role enums" do
    company = Company.create!(name: "Acme")
    team = Team.create!(company: company, name: "Talent")
    user = User.create!(email: "member@example.test", password: "Password123!", password_confirmation: "Password123!")

    membership = described_class.create!(user: user, team: team, role: :hiring_manager)
    expect(membership.role).to eq("hiring_manager")
  end
end
