# frozen_string_literal: true

module AtsSeeds
  module_function

  REQUIRED_MODELS = %w[
    Company
    Department
    JobPosting
    PipelineStage
    Candidate
    Application
  ].freeze

  def run
    missing = REQUIRED_MODELS.reject { |name| Object.const_defined?(name) }
    unless missing.empty?
      puts "[ats seeds] skipped: missing models #{missing.join(', ')}"
      return
    end

    company = build_company
    departments = build_departments(company)
    users = build_users
    jobs = build_job_postings(company, departments)
    stages_by_job = build_pipeline_stages(jobs)
    candidates = build_candidates(company)
    applications = build_applications(candidates, jobs, stages_by_job, users)
    build_interviews(applications, users)

    puts "[ats seeds] created #{jobs.length} jobs, #{candidates.length} candidates, #{applications.length} applications"
  end

  def build_company
    Company.find_or_create_by!(name: "Acme Recruiting") do |company|
      assign_if_supported(company, :slug, "acme-recruiting")
    end
  end

  def build_departments(company)
    %w[Engineering Product Design Sales].map do |name|
      Department.find_or_create_by!(company: company, name: name)
    end
  end

  def build_users
    return [] unless Object.const_defined?("User")

    [
      ["admin@acme-recruiting.test", "Admin User"],
      ["recruiter@acme-recruiting.test", "Recruiter User"],
      ["hiring.manager@acme-recruiting.test", "Hiring Manager"]
    ].map do |email, name|
      User.find_or_create_by!(email: email) do |user|
        assign_if_supported(user, :password, "Password123!")
        assign_if_supported(user, :password_confirmation, "Password123!")
        assign_if_supported(user, :name, name)
      end
    end
  end

  def build_job_postings(company, departments)
    roles = [
      ["Staff Engineer", "Remote", "full_time"],
      ["Product Designer", "New York", "full_time"],
      ["Account Executive", "Austin", "full_time"],
      ["Engineering Manager", "San Francisco", "full_time"]
    ]

    roles.each_with_index.map do |(title, location, employment_type), index|
      department = departments[index % departments.length]

      JobPosting.find_or_create_by!(company: company, department: department, title: title) do |job|
        assign_if_supported(job, :slug, title.parameterize)
        assign_if_supported(job, :location, location)
        assign_if_supported(job, :employment_type, employment_type)
        assign_if_supported(job, :salary_min, 140_000 + (index * 10_000))
        assign_if_supported(job, :salary_max, 200_000 + (index * 10_000))
        assign_if_supported(job, :status, 0)
        assign_if_supported(job, :description, "#{title} role focused on scaling product outcomes.")
        assign_if_supported(job, :requirements, "Rails, product collaboration, and ownership mindset.")
        assign_if_supported(job, :opened_at, Time.current - (index + 3).days)
      end
    end
  end

  def build_pipeline_stages(jobs)
    jobs.each_with_object({}) do |job, index|
      stage_names = %w[Applied Screening Interview Offer Hired]
      stages = stage_names.each_with_index.map do |stage_name, position|
        PipelineStage.find_or_create_by!(job_posting: job, name: stage_name) do |stage|
          assign_if_supported(stage, :position, position)
          assign_if_supported(stage, :kind, position)
        end
      end

      index[job.id] = stages
    end
  end

  def build_candidates(company)
    first_names = %w[Sam Mina Jordan Toni Kai Aria Lena Omar Priya Noah Leo Sofia Alex]
    last_names = %w[Rivera Park Lee Cruz Brooks Patel Ortiz Hassan Shah Kim Miller Nguyen Chen]

    Array.new(25) do |index|
      first_name = first_names[index % first_names.length]
      last_name = last_names[index % last_names.length]
      email = "#{first_name.downcase}.#{last_name.downcase}.#{index + 1}@example.test"

      Candidate.find_or_create_by!(company: company, email: email) do |candidate|
        assign_if_supported(candidate, :first_name, first_name)
        assign_if_supported(candidate, :last_name, last_name)
        assign_if_supported(candidate, :phone, "+1-555-010#{format('%02d', index)}")
        assign_if_supported(candidate, :location, %w[Remote New\ York Austin Chicago].cycle[index % 4])
        assign_if_supported(candidate, :source, %w[referral careers linkedin].cycle[index % 3])
      end
    end
  end

  def build_applications(candidates, jobs, stages_by_job, users)
    applications = []

    40.times do |index|
      candidate = candidates[index % candidates.length]
      job = jobs[index % jobs.length]
      stages = stages_by_job.fetch(job.id)
      stage = stages[index % [stages.length, 4].min]

      application = Application.find_or_create_by!(candidate: candidate, job_posting: job) do |record|
        assign_if_supported(record, :pipeline_stage, stage)
        assign_if_supported(record, :status, index % 5)
        assign_if_supported(record, :applied_at, Time.current - (index + 1).days)
        assign_if_supported(record, :owner, users[index % users.length]) unless users.empty?
      end

      applications << application
    end

    applications
  end

  def build_interviews(applications, users)
    return unless Object.const_defined?("Interview")
    return if users.empty?

    applications.first(12).each_with_index do |application, index|
      Interview.find_or_create_by!(application: application, starts_at: Time.current + index.days) do |interview|
        assign_if_supported(interview, :interviewer, users[index % users.length])
        assign_if_supported(interview, :kind, index % 4)
        assign_if_supported(interview, :ends_at, Time.current + index.days + 45.minutes)
        assign_if_supported(interview, :location, "Video")
        assign_if_supported(interview, :meeting_url, "https://example.test/interviews/#{index + 1}")
      end
    end
  end

  def assign_if_supported(record, attribute, value)
    writer = "#{attribute}="
    record.public_send(writer, value) if record.respond_to?(writer)
  end
end

AtsSeeds.run
