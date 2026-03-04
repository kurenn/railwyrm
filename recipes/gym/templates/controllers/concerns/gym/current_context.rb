# frozen_string_literal: true

module Gym
  module CurrentContext
    extend ActiveSupport::Concern

    ROLE_PRIORITY = %w[admin manager staff trainer].freeze

    included do
      helper_method :current_role, :current_gym_location
    end

    def current_role
      return @current_role if instance_variable_defined?(:@current_role)

      @current_role = if current_user
        explicit = normalized_explicit_role
        explicit.presence || inferred_role_from_email || "staff"
      else
        "guest"
      end
    end

    def current_gym_location
      return @current_gym_location if instance_variable_defined?(:@current_gym_location)

      @current_gym_location = if defined?(GymLocation)
        GymLocation.order(:id).first || GymLocation.create!(
          name: "Main Gym",
          code: "main",
          timezone: Time.zone.tzinfo.name
        )
      end
    end

    private

    def normalized_explicit_role
      return "" unless current_user.respond_to?(:role)

      value = current_user.role.to_s
      ROLE_PRIORITY.include?(value) ? value : ""
    end

    def inferred_role_from_email
      email = current_user&.email.to_s.downcase
      return "admin" if email.start_with?("admin@")
      return "manager" if email.start_with?("manager@")
      return "staff" if email.start_with?("staff@")
      return "trainer" if email.start_with?("trainer@")

      nil
    end
  end
end
