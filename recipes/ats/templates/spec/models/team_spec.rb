# frozen_string_literal: true

require "rails_helper"

RSpec.describe Team, type: :model do
  it "belongs to company" do
    company = Company.create!(name: "Acme")
    team = described_class.create!(company: company, name: "Talent")

    expect(team.company).to eq(company)
  end
end
