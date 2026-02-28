# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :recruiter, :hiring_manager)
  end
end
