# frozen_string_literal: true

module Gym
  class ClassSessionsController < BaseController
    before_action :set_class_session, only: %i[show edit update]

    def index
      authorize ClassSession, :index?
      @class_sessions = class_session_scope.order(starts_at: :asc)
    end

    def show
      authorize @class_session
      @bookings = @class_session.class_bookings.includes(:member).order(created_at: :desc)
      @bookable_members = Member.where(gym_location_id: current_gym_location.id).order(:first_name, :last_name)
    end

    def new
      @class_session = class_session_scope.new(default_class_session_attributes)
      authorize @class_session
    end

    def create
      @class_session = class_session_scope.new(class_session_params)
      authorize @class_session

      if @class_session.save
        redirect_to class_session_path(@class_session), notice: "Class session created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @class_session
    end

    def update
      authorize @class_session

      if @class_session.update(class_session_params)
        redirect_to class_session_path(@class_session), notice: "Class session updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_class_session
      @class_session = class_session_scope.find(params[:id])
    end

    def class_session_scope
      ClassSession.where(gym_location_id: current_gym_location.id)
    end

    def default_class_session_attributes
      start_time = Time.current.change(min: 0) + 1.day
      { starts_at: start_time, ends_at: start_time + 1.hour, capacity: 20, status: :scheduled }
    end

    def class_session_params
      params.require(:class_session).permit(
        :title,
        :instructor_name,
        :starts_at,
        :ends_at,
        :capacity,
        :room,
        :status
      )
    end
  end
end
