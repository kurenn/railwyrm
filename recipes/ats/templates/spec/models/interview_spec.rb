# frozen_string_literal: true

require "rails_helper"

RSpec.describe Interview, type: :model do
  it "requires starts_at" do
    record = described_class.new
    expect(record).not_to be_valid
  end
end
