# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  def index?
    has_role?(:admin, :manager)
  end

  def show?
    index?
  end
end
