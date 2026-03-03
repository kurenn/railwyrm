# frozen_string_literal: true

class FeedbackPolicy < ApplicationPolicy
  def create?
    has_role?(:admin, :recruiter, :hiring_manager, :interviewer)
  end

  def update?
    has_role?(:admin, :recruiter, :hiring_manager)
  end
end
