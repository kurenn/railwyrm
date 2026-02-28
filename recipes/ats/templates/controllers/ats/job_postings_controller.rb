# frozen_string_literal: true

module Ats
  class JobPostingsController < ApplicationController
    before_action :authenticate_user!

    def index
      @job_postings = defined?(JobPosting) ? JobPosting.order(created_at: :desc).limit(50) : []
    end

    def show
      @job_posting = defined?(JobPosting) ? JobPosting.find(params[:id]) : nil
      head :not_found unless @job_posting
    end
  end
end
