# frozen_string_literal: true

class MembershipPlanPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :manager, :staff, :trainer)
  end

  def show?
    index?
  end

  def create?
    has_role?(:admin, :manager)
  end

  def update?
    create?
  end

  def destroy?
    create?
  end
end
