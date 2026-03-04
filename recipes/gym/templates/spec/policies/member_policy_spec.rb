# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberPolicy do
  subject(:policy) { described_class.new(user, double("record")) }

  context "when user is manager" do
    let(:user) { create_authenticated_user(role: :manager) }

    it "allows management" do
      expect(policy.index?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
    end
  end

  context "when user is trainer" do
    let(:user) { create_authenticated_user(role: :trainer) }

    it "allows read only" do
      expect(policy.index?).to be(true)
      expect(policy.create?).to be(false)
      expect(policy.update?).to be(false)
    end
  end
end
