# frozen_string_literal: true

require "rails_helper"

RSpec.describe PipelineStage, type: :model do
  it "requires position per job posting" do
    company = Company.create!(name: "Acme")
    department = Department.create!(company: company, name: "Engineering")
    job = JobPosting.create!(company: company, department: department, title: "Engineer", employment_type: "full_time")

    stage = described_class.new(job_posting: job, name: "Review")
    expect(stage).not_to be_valid
  end
end
