# frozen_string_literal: true

module Ats
  class InterviewsController < BaseController
    before_action :set_application
    before_action :set_interview, only: %i[update destroy]

    def create
      interview = @application.interviews.new(interview_params)
      interview.interviewer ||= current_user
      authorize interview

      if interview.save
        redirect_to application_path(@application), notice: "Interview scheduled."
      else
        redirect_to application_path(@application), alert: interview.errors.full_messages.to_sentence
      end
    end

    def update
      authorize @interview

      if @interview.update(interview_params)
        redirect_to application_path(@application), notice: "Interview updated."
      else
        redirect_to application_path(@application), alert: @interview.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @interview
      @interview.destroy

      redirect_to application_path(@application), notice: "Interview removed."
    end

    private

    def set_application
      @application = Application.find(params[:application_id])
    end

    def set_interview
      @interview = @application.interviews.find(params[:id])
    end

    def interview_params
      params.require(:interview).permit(:kind, :starts_at, :ends_at, :location, :meeting_url)
    end
  end
end
