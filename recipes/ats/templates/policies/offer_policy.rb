# frozen_string_literal: true

class OfferPolicy < ApplicationPolicy
  def create?
    has_role?(:admin, :recruiter, :hiring_manager)
  end

  def update?
    create?
  end
end
