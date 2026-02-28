# frozen_string_literal: true

class ApplicationPolicy
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

  private

  def has_role?(*roles)
    return false unless user

    normalized = roles.map(&:to_s)
    normalized.include?(user_role)
  end

  def user_role
    if user.respond_to?(:role)
      user.role.to_s
    elsif user.respond_to?(:roles)
      Array(user.roles).map(&:to_s).first.to_s
    else
      ""
    end
  end
end
