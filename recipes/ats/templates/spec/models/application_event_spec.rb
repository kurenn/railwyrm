# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationEvent, type: :model do
  it "requires event_type and occurred_at" do
    record = described_class.new

    expect(record).not_to be_valid
    expect(record.errors[:event_type]).to be_present
    expect(record.errors[:occurred_at]).to be_present
  end
end
