# frozen_string_literal: true

module AuthenticationHelpers
  def create_authenticated_user(email: "staff@test.local", role: :staff)
    resolved_email = email_from_role(email, role)

    user = User.create!(
      email: resolved_email,
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    if user.respond_to?(:role=)
      user.update_column(:role, role.to_s)
    end

    user
  end

  def ensure_base_location!
    GymLocation.find_or_create_by!(code: "spec_hq") do |location|
      location.name = "Spec Gym"
      location.timezone = "UTC"
    end
  end

  def ensure_plan!(location = ensure_base_location!)
    MembershipPlan.find_or_create_by!(gym_location: location, name: "Spec Plan") do |plan|
      plan.price_cents = 5000
      plan.billing_cycle = "monthly"
      plan.active = true
    end
  end

  private

  def email_from_role(email, role)
    return email unless email == "staff@test.local"

    "#{role}@test.local"
  end
end

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Warden::Test::Helpers, type: :system
  config.include AuthenticationHelpers

  config.after(type: :system) { Warden.test_reset! }
end
