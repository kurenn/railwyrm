# frozen_string_literal: true

class CandidatePolicy < ApplicationPolicy
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
    has_role?(:admin, :recruiter, :hiring_manager)
  end
end
