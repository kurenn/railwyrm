# frozen_string_literal: true

module Ats
  class PipelineStagesController < BaseController
    before_action :set_job_posting
    before_action :set_pipeline_stage, only: %i[update destroy]

    def create
      authorize @job_posting, :update?

      @pipeline_stage = @job_posting.pipeline_stages.new(pipeline_stage_params)
      @pipeline_stage.position ||= @job_posting.pipeline_stages.maximum(:position).to_i + 1

      if @pipeline_stage.save
        redirect_to job_posting_path(@job_posting), notice: "Stage added."
      else
        redirect_to job_posting_path(@job_posting), alert: @pipeline_stage.errors.full_messages.to_sentence
      end
    end

    def update
      authorize @job_posting, :update?

      if @pipeline_stage.update(pipeline_stage_params)
        redirect_to job_posting_path(@job_posting), notice: "Stage updated."
      else
        redirect_to job_posting_path(@job_posting), alert: @pipeline_stage.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @job_posting, :update?
      @pipeline_stage.destroy

      redirect_to job_posting_path(@job_posting), notice: "Stage removed."
    end

    private

    def set_job_posting
      @job_posting = JobPosting.find(params[:job_posting_id])
    end

    def set_pipeline_stage
      @pipeline_stage = @job_posting.pipeline_stages.find(params[:id])
    end

    def pipeline_stage_params
      params.require(:pipeline_stage).permit(:name, :position, :kind)
    end
  end
end
