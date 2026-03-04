# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
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
end
