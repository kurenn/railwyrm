# frozen_string_literal: true

class MemberPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :manager, :staff, :trainer)
  end

  def show?
    index?
  end

  def create?
    has_role?(:admin, :manager, :staff)
  end

  def update?
    create?
  end

  def destroy?
    has_role?(:admin, :manager)
  end
end
