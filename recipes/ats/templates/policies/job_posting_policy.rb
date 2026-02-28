# frozen_string_literal: true

class JobPostingPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :recruiter, :hiring_manager, :interviewer)
  end

  def show?
    index?
  end

  def create?
    has_role?(:admin, :recruiter)
  end

  def update?
    has_role?(:admin, :recruiter)
  end

  def destroy?
    has_role?(:admin)
  end
end
