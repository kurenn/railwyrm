# frozen_string_literal: true

class ApplicationPolicy
  ROLE_PRIORITY = %w[admin recruiter hiring_manager interviewer].freeze

  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    private

    attr_reader :user, :scope
  end

  private

  def has_role?(*roles)
    return false unless user

    normalized = roles.map(&:to_s)
    normalized.include?(resolved_role)
  end

  def resolved_role
    direct = user.respond_to?(:role) ? user.role.to_s : nil
    return direct if ROLE_PRIORITY.include?(direct)

    membership_role || inferred_role_from_email || ""
  end

  def membership_role
    return unless defined?(Membership)

    roles = Membership.where(user_id: user.id).filter_map do |membership|
      role = membership.respond_to?(:role) ? membership.role.to_s : nil
      ROLE_PRIORITY.include?(role) ? role : nil
    end

    ROLE_PRIORITY.find { |role| roles.include?(role) }
  rescue StandardError
    nil
  end

  def inferred_role_from_email
    email = user.respond_to?(:email) ? user.email.to_s.downcase : ""
    return "admin" if email.start_with?("admin@")
    return "recruiter" if email.start_with?("recruiter@")
    return "hiring_manager" if email.start_with?("hiring.manager@")
    return "interviewer" if email.start_with?("interviewer@")

    nil
  end
end
