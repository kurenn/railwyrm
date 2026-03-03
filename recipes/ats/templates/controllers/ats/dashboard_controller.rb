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
    end
  end
end
