# frozen_string_literal: true

module Ats
  class ApplicationsController < BaseController
    before_action :set_application, only: %i[show update]

    def index
      authorize Application, :index?, policy_class: AtsApplicationPolicy

      @applications = Application.includes(:candidate, :job_posting, :pipeline_stage).order(updated_at: :desc)
      @applications = @applications.where(job_posting_id: params[:job_posting_id]) if params[:job_posting_id]
      @applications = @applications.where(candidate_id: params[:candidate_id]) if params[:candidate_id]
    end

    def show
      authorize @application, policy_class: AtsApplicationPolicy
      @interviews = @application.interviews.order(starts_at: :asc)
      @offers = @application.offers.order(created_at: :desc)
      @feedbacks = Feedback.joins(:interview).where(interviews: { application_id: @application.id }).order(created_at: :desc)
      @available_stages = @application.job_posting.pipeline_stages.order(:position)
    end

    def create
      authorize Application, :create?, policy_class: AtsApplicationPolicy

      payload = params.require(:application)
      job_posting = JobPosting.find(payload.fetch(:job_posting_id, params[:job_posting_id]))
      candidate = Candidate.find(payload.fetch(:candidate_id))
      stage = job_posting.pipeline_stages.order(:position).first

      application = Application.find_or_initialize_by(candidate: candidate, job_posting: job_posting)
      application.pipeline_stage ||= stage
      application.applied_at ||= Time.current
      application.owner ||= current_user

      if application.save
        redirect_to application_path(application), notice: "Application created."
      else
        redirect_back fallback_location: candidate_path(candidate), alert: application.errors.full_messages.to_sentence
      end
    end

    def update
      authorize @application, policy_class: AtsApplicationPolicy

      if @application.update(application_params)
        redirect_to application_path(@application), notice: "Application updated."
      else
        @interviews = @application.interviews.order(starts_at: :asc)
        @offers = @application.offers.order(created_at: :desc)
        @feedbacks = Feedback.joins(:interview).where(interviews: { application_id: @application.id }).order(created_at: :desc)
        @available_stages = @application.job_posting.pipeline_stages.order(:position)
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_application
      @application = Application.includes(:candidate, :job_posting, :pipeline_stage).find(params[:id])
    end

    def application_params
      params.require(:application).permit(:status, :pipeline_stage_id)
    end
  end
end
