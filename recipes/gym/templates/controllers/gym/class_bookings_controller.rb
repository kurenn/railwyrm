# frozen_string_literal: true

module Gym
  class ClassBookingsController < BaseController
    before_action :set_class_session

    def create
      @class_booking = @class_session.class_bookings.new(
        member_id: params[:member_id],
        status: :booked,
        booked_at: Time.current
      )
      authorize @class_booking

      if @class_booking.save
        redirect_to class_session_path(@class_session), notice: "Member booked into class."
      else
        redirect_to class_session_path(@class_session), alert: @class_booking.errors.full_messages.to_sentence
      end
    end

    def update
      @class_booking = @class_session.class_bookings.find(params[:id])
      authorize @class_booking

      status = params[:status].presence || params.dig(:class_booking, :status)
      attributes = { status: status }
      attributes[:canceled_at] = Time.current if status.to_s == "canceled"

      if @class_booking.update(attributes)
        redirect_to class_session_path(@class_session), notice: "Booking updated."
      else
        redirect_to class_session_path(@class_session), alert: @class_booking.errors.full_messages.to_sentence
      end
    end

    def destroy
      @class_booking = @class_session.class_bookings.find(params[:id])
      authorize @class_booking
      @class_booking.destroy

      redirect_to class_session_path(@class_session), notice: "Booking removed."
    end

    private

    def set_class_session
      @class_session = ClassSession.where(gym_location_id: current_gym_location.id).find(params[:class_session_id])
    end
  end
end
