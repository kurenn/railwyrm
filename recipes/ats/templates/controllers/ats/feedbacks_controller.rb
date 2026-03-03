# frozen_string_literal: true

module Ats
  class FeedbacksController < BaseController
    before_action :set_application
    before_action :set_feedback, only: %i[update]

    def create
      interview = @application.interviews.find(params.require(:feedback).fetch(:interview_id))
      feedback = interview.feedbacks.new(feedback_params)
      feedback.reviewer ||= current_user
      authorize feedback

      if feedback.save
        redirect_to application_path(@application), notice: "Feedback submitted."
      else
        redirect_to application_path(@application), alert: feedback.errors.full_messages.to_sentence
      end
    end

    def update
      authorize @feedback

      if @feedback.update(feedback_params)
        redirect_to application_path(@application), notice: "Feedback updated."
      else
        redirect_to application_path(@application), alert: @feedback.errors.full_messages.to_sentence
      end
    end

    private

    def set_application
      @application = Application.find(params[:application_id])
    end

    def set_feedback
      @feedback = Feedback.joins(:interview).where(interviews: { application_id: @application.id }).find(params[:id])
    end

    def feedback_params
      params.require(:feedback).permit(:score, :recommendation, :strengths, :concerns, :summary)
    end
  end
end
