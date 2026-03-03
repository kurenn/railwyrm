# frozen_string_literal: true

module Ats
  class JobPostingsController < BaseController
    before_action :set_job_posting, only: %i[show edit update destroy]

    def index
      authorize JobPosting, :index?

      @status_filter = params[:status].presence
      @job_postings = JobPosting.includes(:department).order(created_at: :desc)
      @job_postings = @job_postings.where(status: @status_filter) if @status_filter
    end

    def show
      authorize @job_posting
      @pipeline_stages = @job_posting.pipeline_stages.order(:position)
      @applications = @job_posting.applications.includes(:candidate, :pipeline_stage).order(updated_at: :desc)
    end

    def new
      @job_posting = JobPosting.new
      authorize @job_posting
      preload_dependencies
    end

    def create
      @job_posting = JobPosting.new(job_posting_params)
      @job_posting.company ||= current_company || Company.first
      @job_posting.department ||= default_department_for(@job_posting.company)
      authorize @job_posting

      apply_transition(@job_posting)

      if @job_posting.save
        redirect_to job_posting_path(@job_posting), notice: "Job posting created."
      else
        preload_dependencies
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @job_posting
      preload_dependencies
    end

    def update
      authorize @job_posting
      @job_posting.assign_attributes(job_posting_params)
      apply_transition(@job_posting)

      if @job_posting.save
        redirect_to job_posting_path(@job_posting), notice: "Job posting updated."
      else
        preload_dependencies
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @job_posting
      @job_posting.destroy

      redirect_to job_postings_path, notice: "Job posting archived."
    end

    private

    def set_job_posting
      @job_posting = JobPosting.find(params[:id])
    end

    def preload_dependencies
      @departments = Department.order(:name)
    end

    def default_department_for(company)
      Department.find_by(company_id: company&.id) || Department.first
    end

    def apply_transition(job_posting)
      transition = params[:transition].presence || (params[:publish_now] == "1" ? "publish" : nil)
      case transition
      when "publish" then job_posting.publish!
      when "unpublish" then job_posting.unpublish!
      when "close" then job_posting.close!
      end
    end

    def job_posting_params
      params.require(:job_posting).permit(
        :department_id,
        :title,
        :location,
        :employment_type,
        :salary_min,
        :salary_max,
        :description,
        :requirements,
        :status
      )
    end
  end
end
