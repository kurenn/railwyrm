# frozen_string_literal: true

class InterviewPolicy < ApplicationPolicy
  def show?
    has_role?(:admin, :recruiter, :hiring_manager, :interviewer)
  end

  def create?
    has_role?(:admin, :recruiter, :hiring_manager)
  end

  def update?
    create?
  end

  def destroy?
    has_role?(:admin, :recruiter)
  end
end
