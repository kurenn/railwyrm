# frozen_string_literal: true

class AtsApplicationPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :recruiter, :hiring_manager, :interviewer)
  end

  def show?
    index?
  end

  def create?
    has_role?(:admin, :recruiter, :hiring_manager)
  end

  def update?
    create?
  end
end
