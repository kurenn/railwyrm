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

  before_validation :ensure_slug
  after_create :ensure_default_pipeline_stages

  scope :published, -> { open.order(updated_at: :desc) }

  def publish!
    self.status = :open
    self.opened_at ||= Time.current
  end

  def unpublish!
    self.status = :draft
  end

  def close!
    self.status = :closed
    self.closed_at ||= Time.current
  end

  private

  def ensure_default_pipeline_stages
    return unless pipeline_stages.empty?

    %w[Applied Screening Interview Offer Hired].each_with_index do |name, position|
      pipeline_stages.create(name: name, position: position, kind: position)
    end
  end

  def ensure_slug
    self.slug = title.to_s.parameterize if slug.blank? && title.present?
  end

  def salary_range_is_valid
    return if salary_min.blank? || salary_max.blank?
    return unless salary_min > salary_max

    errors.add(:salary_min, "must be less than or equal to salary_max")
  end
end
