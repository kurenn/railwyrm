# frozen_string_literal: true

class Candidate < ApplicationRecord
  belongs_to :company
  has_many :applications, dependent: :destroy
  has_many :candidate_taggings, dependent: :destroy
  has_many :candidate_tags, through: :candidate_taggings

  has_one_attached :resume

  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: { scope: :company_id }

  before_validation :normalize_email

  scope :search, lambda { |query|
    token = "%#{ActiveRecord::Base.sanitize_sql_like(query.to_s.downcase)}%"
    where("LOWER(first_name) LIKE :token OR LOWER(last_name) LIKE :token OR LOWER(email) LIKE :token", token: token)
  }

  def full_name
    [first_name, last_name].compact.join(" ")
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
