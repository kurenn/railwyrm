# frozen_string_literal: true

module Ats
  module CurrentContext
    extend ActiveSupport::Concern

    ROLE_PRIORITY = %w[admin recruiter hiring_manager interviewer].freeze

    included do
      helper_method :current_company, :current_role
    end

    def current_company
      return @current_company if instance_variable_defined?(:@current_company)

      @current_company = if defined?(Company)
                           company_from_membership || Company.first
                         end
    end

    def current_role
      return @current_role if instance_variable_defined?(:@current_role)

      @current_role = if current_user
        roles = []
        roles << normalized_explicit_role
        roles.concat(membership_roles)
        roles << email_role
        ROLE_PRIORITY.find { |role| roles.include?(role) } || "interviewer"
      else
        "guest"
      end
    end

    private

    def normalized_explicit_role
      return "" unless current_user.respond_to?(:role)

      candidate = current_user.role.to_s
      ROLE_PRIORITY.include?(candidate) ? candidate : ""
    end

    def membership_roles
      return [] unless defined?(Membership)

      Membership.where(user_id: current_user.id).filter_map do |membership|
        role = membership.respond_to?(:role) ? membership.role.to_s : nil
        ROLE_PRIORITY.include?(role) ? role : nil
      end
    rescue StandardError
      []
    end

    def company_from_membership
      return unless current_user && defined?(Membership)

      Membership.includes(team: :company).find_by(user_id: current_user.id)&.team&.company
    rescue StandardError
      nil
    end

    def email_role
      email = current_user&.email.to_s.downcase
      return "admin" if email.start_with?("admin@")
      return "recruiter" if email.start_with?("recruiter@")
      return "hiring_manager" if email.start_with?("hiring.manager@")
      return "interviewer" if email.start_with?("interviewer@")

      ""
    end
  end
end
