# frozen_string_literal: true

module Gym
  class DashboardController < BaseController
    def show
      authorize Member, :index?

      location = current_gym_location
      @dashboard_metrics = {
        members: member_scope.count,
        visits_today: visit_scope.where(checked_in_at: Time.current.beginning_of_day..Time.current.end_of_day).count,
        active_plans: plan_scope.where(active: true).count,
        upcoming_classes: class_session_scope.where(starts_at: Time.current..1.week.from_now).count
      }
      @recent_visits = visit_scope.includes(:member).order(checked_in_at: :desc).limit(8)
      @upcoming_classes = class_session_scope.order(:starts_at).limit(5)
      @location = location
    end

    private

    def member_scope
      Member.where(gym_location_id: current_gym_location.id)
    end

    def visit_scope
      Visit.where(gym_location_id: current_gym_location.id)
    end

    def class_session_scope
      ClassSession.where(gym_location_id: current_gym_location.id)
    end

    def plan_scope
      MembershipPlan.where(gym_location_id: current_gym_location.id)
    end
  end
end
