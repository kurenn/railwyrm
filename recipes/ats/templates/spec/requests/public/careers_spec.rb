# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public careers", type: :request do
  it "renders the careers index" do
    company = Company.create!(name: "Acme")
    department = Department.create!(company: company, name: "Engineering")
    JobPosting.create!(company: company, department: department, title: "Engineer", employment_type: "full_time", status: :open)

    get careers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Join our team")
    expect(response.body).to include("Engineer")
  end
end
