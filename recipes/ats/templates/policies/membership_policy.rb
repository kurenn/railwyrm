# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
  def create?
    has_role?(:admin, :recruiter)
  end

  def update?
    create?
  end

  def destroy?
    has_role?(:admin)
  end
end
