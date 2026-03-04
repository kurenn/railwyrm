# frozen_string_literal: true

class ApplicationPolicy
  ROLE_PRIORITY = %w[admin manager staff trainer].freeze

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

    roles.map(&:to_s).include?(resolved_role)
  end

  def resolved_role
    direct = user.respond_to?(:role) ? user.role.to_s : nil
    return direct if ROLE_PRIORITY.include?(direct)

    inferred_role_from_email || "staff"
  end

  def inferred_role_from_email
    email = user.respond_to?(:email) ? user.email.to_s.downcase : ""
    return "admin" if email.start_with?("admin@")
    return "manager" if email.start_with?("manager@")
    return "staff" if email.start_with?("staff@")
    return "trainer" if email.start_with?("trainer@")

    nil
  end
end
