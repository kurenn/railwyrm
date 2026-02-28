# frozen_string_literal: true

class JobPosting < ApplicationRecord
  belongs_to :company
  belongs_to :department

  has_many :pipeline_stages, dependent: :destroy
  has_many :applications, dependent: :destroy

  enum :status, {
    draft: 0,
    open: 1,
    closed: 2,
    archived: 3
  }, default: :draft

  validates :title, :employment_type, presence: true
  validates :slug, uniqueness: true, allow_nil: true
  validate :salary_range_is_valid

  private

  def salary_range_is_valid
    return if salary_min.blank? || salary_max.blank?
    return unless salary_min > salary_max

    errors.add(:salary_min, "must be less than or equal to salary_max")
  end
end
