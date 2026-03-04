# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportPolicy do
  it "allows manager access" do
    user = create_authenticated_user(role: :manager)
    policy = described_class.new(user, :report)

    expect(policy.index?).to be(true)
  end

  it "denies trainer access" do
    user = create_authenticated_user(role: :trainer)
    policy = described_class.new(user, :report)

    expect(policy.index?).to be(false)
  end
end
