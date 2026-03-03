# frozen_string_literal: true

module Ats
  class DashboardController < BaseController
    def show
      authorize JobPosting, :index?

      @dashboard_metrics = {
        open_roles: JobPosting.open.count,
        active_candidates: Candidate.count,
        active_applications: Application.where.not(status: :rejected).count,
        interviews_this_week: Interview.where(starts_at: Time.current.beginning_of_week..Time.current.end_of_week).count
      }
      @recent_applications = Application.includes(:candidate, :job_posting).order(updated_at: :desc).limit(8)
      @site_traffic_bars = [58, 41, 45, 31, 66, 79, 66, 58, 53, 30, 37, 41, 45, 39, 31, 22, 31, 37, 53, 45, 78, 68, 58, 53, 26, 31, 37, 41, 26, 22, 31, 45, 58, 53, 66, 79, 68, 58, 53, 41, 35, 31, 37, 45, 53, 58, 53, 45, 41, 31, 53, 58, 53, 58, 66]
    end
  end
end
