# frozen_string_literal: true

module Ats
  class CandidatesController < BaseController
    before_action :set_candidate, only: %i[show edit update]

    def index
      authorize Candidate, :index?

      @query = params[:q].to_s.strip
      @candidates = Candidate.order(created_at: :desc)
      @candidates = @candidates.search(@query) if @query.present?
      @candidates = @candidates.limit(100)
    end

    def show
      authorize @candidate
      @applications = @candidate.applications.includes(:job_posting, :pipeline_stage).order(updated_at: :desc)
      @job_options = JobPosting.open.order(:title)
    end

    def new
      @candidate = Candidate.new
      authorize @candidate
    end

    def create
      @candidate = Candidate.new(candidate_params)
      @candidate.company ||= current_company || Company.first
      authorize @candidate

      if @candidate.save
        redirect_to candidate_path(@candidate), notice: "Candidate created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @candidate
    end

    def update
      authorize @candidate

      if @candidate.update(candidate_params)
        redirect_to candidate_path(@candidate), notice: "Candidate updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_candidate
      @candidate = Candidate.find(params[:id])
    end

    def candidate_params
      params.require(:candidate).permit(
        :first_name,
        :last_name,
        :email,
        :phone,
        :location,
        :linkedin_url,
        :portfolio_url,
        :source,
        :notes,
        :resume
      )
    end
  end
end
