# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe JobPostingPolicy do
  subject(:policy) { described_class.new(user, double("record")) }

  context "when user is an admin" do
    let(:user) { OpenStruct.new(role: "admin") }

    it "allows management actions" do
      expect(policy.index?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.destroy?).to be(true)
    end
  end

  context "when user is a recruiter" do
    let(:user) { OpenStruct.new(role: "recruiter") }

    it "allows create/update but blocks destroy" do
      expect(policy.index?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.destroy?).to be(false)
    end
  end

  context "when user is missing" do
    let(:user) { nil }

    it "denies access" do
      expect(policy.index?).to be(false)
      expect(policy.create?).to be(false)
    end
  end
end
