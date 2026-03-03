# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReportPolicy do
  subject(:policy) { described_class.new(user, :report) }

  context "when user is hiring manager" do
    let(:user) { create_authenticated_user(email: "hm.policy@test.local", role: :hiring_manager) }

    it "allows report access" do
      expect(policy.index?).to be(true)
    end
  end

  context "when user is interviewer" do
    let(:user) { create_authenticated_user(email: "iv.policy@test.local", role: :interviewer) }

    it "denies report access" do
      expect(policy.index?).to be(false)
    end
  end
end
