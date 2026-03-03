# frozen_string_literal: true

module Ats
  class PipelineBoardController < BaseController
    def show
      authorize Application, :index?, policy_class: AtsApplicationPolicy

      @job_postings = JobPosting.open.order(:title)
      @job_posting = @job_postings.find_by(id: params[:job_posting_id]) || @job_postings.first || JobPosting.order(:title).first
      @pipeline_stages = @job_posting ? @job_posting.pipeline_stages.order(:position) : []
      @applications_by_stage = @pipeline_stages.index_with do |stage|
        @job_posting.applications.includes(:candidate).where(pipeline_stage_id: stage.id).order(updated_at: :desc)
      end
    end
  end
end
