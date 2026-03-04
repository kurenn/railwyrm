# frozen_string_literal: true

class ClassBookingPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :manager, :staff, :trainer)
  end

  def show?
    index?
  end

  def create?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index?
  end
end
