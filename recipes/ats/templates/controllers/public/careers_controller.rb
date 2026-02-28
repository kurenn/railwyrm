# frozen_string_literal: true

module Public
  class CareersController < ApplicationController
    def index
      @job_postings = if defined?(JobPosting)
                        JobPosting.order(created_at: :desc).limit(50)
                      else
                        []
                      end
    end

    def show
      @job_posting = defined?(JobPosting) ? JobPosting.find(params[:id]) : nil
      head :not_found unless @job_posting
    end
  end
end
