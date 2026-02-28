# frozen_string_literal: true

module Ats
  class DashboardController < ApplicationController
    before_action :authenticate_user!

    def show
      @dashboard_metrics = {
        open_roles: safe_count("JobPosting"),
        active_candidates: safe_count("Candidate"),
        active_applications: safe_count("Application")
      }
    end

    private

    def safe_count(model_name)
      model_name.constantize.count
    rescue NameError
      0
    end
  end
end
