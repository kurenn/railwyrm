# frozen_string_literal: true

require "rails_helper"

RSpec.describe JobPostingPolicy do
  subject(:policy) { described_class.new(user, double("record")) }

  context "when user has admin membership" do
    let(:user) { create_authenticated_user(email: "admin.policy@test.local", role: :admin) }

    it "allows full management" do
      expect(policy.index?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.destroy?).to be(true)
    end
  end

  context "when user has interviewer membership" do
    let(:user) { create_authenticated_user(email: "interviewer.policy@test.local", role: :interviewer) }

    it "can read but cannot edit" do
      expect(policy.index?).to be(true)
      expect(policy.create?).to be(false)
      expect(policy.update?).to be(false)
    end
  end
end
