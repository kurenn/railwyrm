# frozen_string_literal: true

require "rails_helper"

RSpec.describe JobPosting, type: :model do
  it "validates salary ranges" do
    company = Company.create!(name: "Acme")
    department = Department.create!(company: company, name: "Engineering")

    record = described_class.new(
      company: company,
      department: department,
      title: "Backend Engineer",
      employment_type: "full_time",
      salary_min: 200_000,
      salary_max: 150_000
    )

    expect(record).not_to be_valid
    expect(record.errors[:salary_min]).to include("must be less than or equal to salary_max")
  end

  it "creates default pipeline stages after creation" do
    company = Company.create!(name: "Acme")
    department = Department.create!(company: company, name: "Engineering")

    job = described_class.create!(company: company, department: department, title: "Designer", employment_type: "full_time")

    expect(job.pipeline_stages.count).to eq(5)
  end
end
