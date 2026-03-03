# frozen_string_literal: true

require "rails_helper"

RSpec.describe Application, type: :model do
  it "creates audit events when status changes" do
    company = Company.create!(name: "Acme")
    department = Department.create!(company: company, name: "Engineering")
    job = JobPosting.create!(company: company, department: department, title: "Engineer", employment_type: "full_time")
    stage = job.pipeline_stages.order(:position).first
    candidate = Candidate.create!(company: company, first_name: "Sam", last_name: "Rivera", email: "sam@example.test")
    owner = User.create!(email: "owner@example.test", password: "Password123!", password_confirmation: "Password123!")

    application = described_class.create!(candidate: candidate, job_posting: job, pipeline_stage: stage, owner: owner)
    application.update!(status: :interview)

    expect(application.application_events.where(event_type: "application_created")).to exist
    expect(application.application_events.where(event_type: "status_changed")).to exist
  end
end
