# frozen_string_literal: true

class Company < ApplicationRecord
  has_many :teams, dependent: :destroy
  has_many :departments, dependent: :destroy
  has_many :job_postings, dependent: :destroy
  has_many :candidates, dependent: :destroy
  has_many :candidate_tags, dependent: :destroy

  validates :name, presence: true
  validates :slug, uniqueness: true, allow_nil: true

  before_validation :ensure_slug

  private

  def ensure_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
