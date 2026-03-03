# frozen_string_literal: true

require "rails_helper"

RSpec.describe Company, type: :model do
  it "generates slug from name" do
    company = described_class.create!(name: "My Company")

    expect(company.slug).to eq("my-company")
  end
end
