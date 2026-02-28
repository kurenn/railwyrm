# frozen_string_literal: true

class HardenAtsConstraints < ActiveRecord::Migration[7.1]
  def change
    add_unique_indexes
    add_salary_check_constraint
  end

  private

  def add_unique_indexes
    add_index :companies, :slug, unique: true, if_not_exists: true
    add_index :job_postings, :slug, unique: true, if_not_exists: true
    add_index :memberships, %i[user_id team_id], unique: true, if_not_exists: true
    add_index :departments, %i[company_id name], unique: true, if_not_exists: true
    add_index :pipeline_stages, %i[job_posting_id position], unique: true, if_not_exists: true
    add_index :candidate_taggings, %i[candidate_id candidate_tag_id], unique: true, if_not_exists: true
  end

  def add_salary_check_constraint
    return unless table_exists?(:job_postings)

    add_check_constraint(
      :job_postings,
      "salary_min IS NULL OR salary_max IS NULL OR salary_min <= salary_max",
      name: "job_postings_salary_range",
      validate: false
    ) unless check_constraint_exists?(:job_postings, name: "job_postings_salary_range")
  end
end
