# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe ReportPolicy do
  subject(:policy) { described_class.new(user, double("record")) }

  context "when user is hiring manager" do
    let(:user) { OpenStruct.new(role: "hiring_manager") }

    it "allows report access" do
      expect(policy.index?).to be(true)
    end
  end

  context "when user is interviewer" do
    let(:user) { OpenStruct.new(role: "interviewer") }

    it "denies report access" do
      expect(policy.index?).to be(false)
    end
  end
end
