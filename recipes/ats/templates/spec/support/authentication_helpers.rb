# frozen_string_literal: true

module AuthenticationHelpers
  def create_authenticated_user(email: "recruiter@test.local", role: :recruiter)
    user = User.create!(
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    company = Company.find_or_create_by!(name: "Spec Company") do |record|
      record.slug = "spec-company"
    end
    team = Team.find_or_create_by!(company: company, name: "Talent")
    Membership.find_or_create_by!(user: user, team: team) { |membership| membership.role = role }

    user
  end

  def ensure_base_company!
    Company.find_or_create_by!(name: "Spec Company") { |record| record.slug = "spec-company" }
  end

  def ensure_department!(company = ensure_base_company!)
    Department.find_or_create_by!(company: company, name: "Engineering")
  end
end

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Warden::Test::Helpers, type: :system
  config.include AuthenticationHelpers

  config.after(type: :system) { Warden.test_reset! }
end
