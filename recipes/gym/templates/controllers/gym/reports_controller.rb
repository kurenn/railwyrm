# frozen_string_literal: true

module Gym
  class ReportsController < BaseController
    def index
      authorize :report, :index?

      @location = current_gym_location
      @active_member_count = member_scope.active.count
      @visits_last_30_days = visit_scope.where(checked_in_at: 30.days.ago..Time.current).count
      @new_members_last_30_days = member_scope.where(joined_on: 30.days.ago.to_date..Date.current).count
      @upcoming_class_count = class_session_scope.where(starts_at: Time.current..7.days.from_now).count
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
  end
end
