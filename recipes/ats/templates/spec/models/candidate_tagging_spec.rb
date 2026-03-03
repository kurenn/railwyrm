# frozen_string_literal: true

require "rails_helper"

RSpec.describe CandidateTagging, type: :model do
  it "belongs to candidate and tag" do
    expect(described_class.reflect_on_association(:candidate)).to be_present
    expect(described_class.reflect_on_association(:candidate_tag)).to be_present
  end
end
