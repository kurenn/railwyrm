# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  it "has email attribute" do
    expect(described_class.new).to respond_to(:email)
  end
end
