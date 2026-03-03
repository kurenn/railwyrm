# frozen_string_literal: true

module Public
  class CareersController < ApplicationController
    def index
      @job_postings = JobPosting.open.includes(:department).order(created_at: :desc)
    end

    def show
      @job_posting = JobPosting.open.find(params[:id])
      @candidate = Candidate.new
    end
  end
end
