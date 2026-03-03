# frozen_string_literal: true

require "csv"

module Ats
  class ReportsController < BaseController
    def index
      authorize :report, :index?

      @applications_by_status = Application.group(:status).count
      @applications_by_department = Application.joins(job_posting: :department).group("departments.name").count
      @offers_by_status = Offer.group(:status).count

      respond_to do |format|
        format.html
        format.csv do
          send_data(applications_csv, filename: "ats-applications-#{Date.current}.csv")
        end
      end
    end

    private

    def applications_csv
      CSV.generate(headers: true) do |csv|
        csv << %w[id candidate_email job_title status applied_at]
        Application.includes(:candidate, :job_posting).order(created_at: :desc).find_each do |application|
          csv << [
            application.id,
            application.candidate&.email,
            application.job_posting&.title,
            application.status,
            application.applied_at
          ]
        end
      end
    end
  end
end
