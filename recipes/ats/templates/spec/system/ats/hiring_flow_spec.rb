# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ATS hiring flow", type: :system do
  it "creates job, candidate, and application" do
    driven_by(:rack_test)

    user = create_authenticated_user(email: "recruiter.flow@test.local", role: :recruiter)
    company = ensure_base_company!
    department = ensure_department!(company)

    login_as user, scope: :user

    visit new_job_posting_path
    fill_in "Title", with: "Growth Engineer"
    select department.name, from: "Department"
    fill_in "Location", with: "Remote"
    fill_in "Employment type", with: "full_time"
    fill_in "Salary min", with: "120000"
    fill_in "Salary max", with: "170000"
    fill_in "Description", with: "Work on growth systems"
    fill_in "Requirements", with: "Rails"
    click_button "Save and publish"

    expect(page).to have_content("Job posting created")
    expect(page).to have_content("Growth Engineer")

    visit new_candidate_path
    fill_in "First name", with: "Mila"
    fill_in "Last name", with: "Stone"
    fill_in "Email", with: "mila.stone@test.local"
    fill_in "Location", with: "Monterrey"
    click_button "Save candidate"

    expect(page).to have_content("Candidate created")
    expect(page).to have_content("Mila Stone")

    select "Growth Engineer", from: "application_job_posting_id"
    click_button "Create application"

    expect(page).to have_content("Application created")
  end
end
