# frozen_string_literal: true

require "rails_helper"

RSpec.describe Offer, type: :model do
  it "allows known statuses" do
    expect(described_class::STATUSES).to include("sent", "accepted")
  end
end
