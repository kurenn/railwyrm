# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ATS job postings", type: :request do
  it "allows recruiter to create and publish job postings" do
    user = create_authenticated_user
    company = ensure_base_company!
    department = ensure_department!(company)
    sign_in user

    post job_postings_path, params: {
      job_posting: {
        department_id: department.id,
        title: "Platform Engineer",
        location: "Remote",
        employment_type: "full_time",
        salary_min: 120_000,
        salary_max: 180_000,
        description: "Build platform services",
        requirements: "Rails and PostgreSQL"
      },
      publish_now: "1"
    }

    expect(response).to redirect_to(job_posting_path(JobPosting.last))
    expect(JobPosting.last).to be_open
  end
end
