# frozen_string_literal: true

require "rails_helper"

RSpec.describe CandidateTag, type: :model do
  it "requires name" do
    expect(described_class.new).not_to be_valid
  end
end
