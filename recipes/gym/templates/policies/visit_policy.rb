# frozen_string_literal: true

class VisitPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :manager, :staff, :trainer)
  end

  def show?
    index?
  end

  def create?
    has_role?(:admin, :manager, :staff, :trainer)
  end

  def update?
    has_role?(:admin, :manager, :staff)
  end
end
