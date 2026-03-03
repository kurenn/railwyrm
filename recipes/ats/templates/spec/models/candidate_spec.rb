# frozen_string_literal: true

require "rails_helper"

RSpec.describe Candidate, type: :model do
  it "normalizes email and exposes full name" do
    company = Company.create!(name: "Acme")

    candidate = described_class.create!(
      company: company,
      first_name: "Sienna",
      last_name: "Hewitt",
      email: " SIENNA@EXAMPLE.COM "
    )

    expect(candidate.email).to eq("sienna@example.com")
    expect(candidate.full_name).to eq("Sienna Hewitt")
  end
end
