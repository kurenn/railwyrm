# frozen_string_literal: true

class Candidate < ApplicationRecord
  belongs_to :company
  has_many :applications, dependent: :destroy
  has_many :candidate_taggings, dependent: :destroy
  has_many :candidate_tags, through: :candidate_taggings

  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: { scope: :company_id }
end
