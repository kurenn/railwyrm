# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public applications", type: :request do
  it "creates candidate and application from career page" do
    company = Company.create!(name: "Acme")
    department = Department.create!(company: company, name: "Engineering")
    job = JobPosting.create!(company: company, department: department, title: "Engineer", employment_type: "full_time", status: :open)

    expect do
      post career_applications_path(job), params: {
        candidate: {
          first_name: "Public",
          last_name: "Applicant",
          email: "public@applicant.test",
          location: "Remote"
        }
      }
    end.to change(Application, :count).by(1)

    expect(response).to redirect_to(careers_path)
  end
end
