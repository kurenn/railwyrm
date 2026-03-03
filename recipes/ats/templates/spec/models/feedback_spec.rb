# frozen_string_literal: true

require "rails_helper"

RSpec.describe Feedback, type: :model do
  it "validates score range" do
    record = described_class.new(score: 7)

    expect(record).not_to be_valid
  end
end
