# frozen_string_literal: true

module GymSeeds
  module_function

  def run
    return unless defined?(GymLocation)

    location = GymLocation.find_or_create_by!(code: "hq") do |gym|
      gym.name = "Iron Peak Downtown"
      gym.timezone = "America/Monterrey"
    end

    plans = [
      { name: "Basic", price_cents: 3900, billing_cycle: "monthly" },
      { name: "Pro", price_cents: 5900, billing_cycle: "monthly" },
      { name: "Annual", price_cents: 49900, billing_cycle: "yearly" }
    ]

    plans.each do |plan|
      MembershipPlan.find_or_create_by!(gym_location: location, name: plan.fetch(:name)) do |record|
        record.price_cents = plan.fetch(:price_cents)
        record.billing_cycle = plan.fetch(:billing_cycle)
        record.active = true
      end
    end

    8.times do |index|
      member = Member.find_or_create_by!(email: "member#{index + 1}@example.com") do |record|
        record.gym_location = location
        record.first_name = "Member"
        record.last_name = "#{index + 1}"
        record.phone = "+1-555-010#{index}"
        record.status = 1
        record.joined_on = Date.current - rand(1..120)
      end

      Visit.find_or_create_by!(member: member, gym_location: location, checked_in_at: Time.current - rand(1..96).hours) do |visit|
        visit.checked_out_at = visit.checked_in_at + rand(1..2).hours
        visit.source = "front_desk"
      end
    end

    puts "Gym seed data loaded"
  end
end

GymSeeds.run
