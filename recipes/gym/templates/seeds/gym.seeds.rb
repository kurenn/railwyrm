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
      { name: "Elite", price_cents: 7900, billing_cycle: "monthly" },
      { name: "Annual", price_cents: 49900, billing_cycle: "yearly" }
    ]

    created_plans = plans.map do |plan|
      MembershipPlan.find_or_create_by!(gym_location: location, name: plan.fetch(:name)) do |record|
        record.price_cents = plan.fetch(:price_cents)
        record.billing_cycle = plan.fetch(:billing_cycle)
        record.active = true
      end
    end

    members = 25.times.map do |index|
      Member.find_or_create_by!(email: "member#{index + 1}@example.com") do |record|
        record.gym_location = location
        record.first_name = "Member"
        record.last_name = "#{index + 1}"
        record.phone = "+1-555-010#{index % 10}"
        record.status = index % 8 == 0 ? :paused : :active
        record.joined_on = Date.current - rand(1..180)
      end
    end

    members.each_with_index do |member, index|
      plan = created_plans[index % created_plans.length]
      Membership.find_or_create_by!(member: member, membership_plan: plan) do |membership|
        membership.starts_on = Date.current - rand(1..120)
        membership.ends_on = Date.current + 30
        membership.status = index % 6 == 0 ? :trial : :active
        membership.auto_renew = true
      end

      rand(3..5).times do |offset|
        checked_in = Time.current - (offset + 1).days + rand(7..19).hours
        Visit.find_or_create_by!(member: member, gym_location: location, checked_in_at: checked_in) do |visit|
          visit.checked_out_at = checked_in + rand(45..120).minutes
          visit.source = "front_desk"
        end
      end
    end

    class_names = ["HIIT", "Strength", "Spin", "Yoga"].freeze
    instructors = ["Coach Alex", "Coach Maya", "Coach Leo"].freeze
    rooms = ["Room A", "Room B", "Main Floor"].freeze
    capacities = [12, 16, 20].freeze

    sessions = 12.times.map do |index|
      starts_at = Time.current.beginning_of_day + (index + 1).days + [6, 7, 18, 19].sample.hours
      ClassSession.find_or_create_by!(
        gym_location: location,
        title: class_names[index % class_names.length],
        starts_at: starts_at
      ) do |session|
        session.instructor_name = instructors[index % instructors.length]
        session.ends_at = starts_at + 1.hour
        session.capacity = capacities[index % capacities.length]
        session.room = rooms[index % rooms.length]
        session.status = :scheduled
      end
    end

    sessions.each do |session|
      members.sample(4).each do |member|
        ClassBooking.find_or_create_by!(class_session: session, member: member) do |booking|
          booking.status = :booked
          booking.booked_at = Time.current - rand(1..5).days
        end
      end
    end

    seed_users!

    puts "Gym seed data loaded"
  end

  def seed_users!
    return unless defined?(User)

    default_password = "Password123!"
    %w[admin manager staff trainer].each do |role|
      email = "#{role}@gym.local"
      User.find_or_create_by!(email: email) do |user|
        user.password = default_password
        user.password_confirmation = default_password
      end
    end
  end
end

GymSeeds.run
