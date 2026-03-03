# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public careers", type: :system do
  it "allows application submission" do
    driven_by(:rack_test)

    company = Company.create!(name: "Acme")
    department = Department.create!(company: company, name: "Engineering")
    job = JobPosting.create!(company: company, department: department, title: "Engineer", employment_type: "full_time", status: :open)

    visit career_path(job)
    fill_in "First name", with: "Nina"
    fill_in "Last name", with: "Test"
    fill_in "Email", with: "nina@test.local"
    click_button "Submit application"

    expect(page).to have_content("Application submitted")
  end
end
