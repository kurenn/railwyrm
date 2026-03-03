# frozen_string_literal: true

module Public
  class ApplicationsController < ApplicationController
    def create
      job_posting = JobPosting.open.find(params[:career_id])
      candidate = find_or_build_candidate(job_posting.company)

      unless candidate.save
        redirect_to career_path(job_posting), alert: candidate.errors.full_messages.to_sentence
        return
      end

      stage = job_posting.pipeline_stages.order(:position).first
      application = Application.find_or_initialize_by(candidate: candidate, job_posting: job_posting)
      application.pipeline_stage ||= stage
      application.applied_at ||= Time.current
      application.owner ||= default_owner

      if application.save
        redirect_to careers_path, notice: "Application submitted. Our team will contact you soon."
      else
        redirect_to career_path(job_posting), alert: application.errors.full_messages.to_sentence
      end
    end

    private

    def find_or_build_candidate(company)
      attrs = candidate_params
      candidate = Candidate.find_or_initialize_by(company: company, email: attrs.fetch(:email))
      candidate.assign_attributes(attrs)
      candidate
    end

    def candidate_params
      params.require(:candidate).permit(
        :first_name,
        :last_name,
        :email,
        :phone,
        :location,
        :linkedin_url,
        :portfolio_url,
        :notes
      )
    end

    def default_owner
      User.find_by(email: "recruiter@acme-recruiting.test") || User.first || bootstrap_owner!
    end

    def bootstrap_owner!
      User.create!(
        email: "intake@acme-recruiting.test",
        password: "Password123!",
        password_confirmation: "Password123!"
      )
    end
  end
end
