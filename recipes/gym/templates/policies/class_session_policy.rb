# frozen_string_literal: true

class ClassSessionPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :manager, :staff, :trainer)
  end

  def show?
    index?
  end

  def create?
    has_role?(:admin, :manager, :trainer)
  end

  def update?
    create?
  end

  def destroy?
    has_role?(:admin, :manager)
  end
end
