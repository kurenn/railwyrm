# frozen_string_literal: true

require "rails_helper"

RSpec.describe Department, type: :model do
  it "requires unique name per company" do
    company = Company.create!(name: "Acme")
    described_class.create!(company: company, name: "Engineering")

    duplicate = described_class.new(company: company, name: "Engineering")
    expect(duplicate).not_to be_valid
  end
end
