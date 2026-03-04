# frozen_string_literal: true

module Gym
  class VisitsController < BaseController
    def index
      authorize Visit, :index?

      @members = member_scope.order(:first_name, :last_name)
      @visits = visit_scope.includes(:member).order(checked_in_at: :desc).limit(100)
    end

    def create
      member = member_scope.find(params[:member_id])
      visit = visit_scope.new(
        member: member,
        gym_location: current_gym_location,
        checked_in_at: Time.current,
        source: params[:source].presence || "front_desk"
      )
      authorize visit

      if visit.save
        redirect_to visits_path, notice: "Visit recorded for #{member.full_name}."
      else
        redirect_to visits_path, alert: visit.errors.full_messages.to_sentence
      end
    end

    private

    def member_scope
      Member.where(gym_location_id: current_gym_location.id)
    end

    def visit_scope
      Visit.where(gym_location_id: current_gym_location.id)
    end
  end
end
