# frozen_string_literal: true

class CandidateTag < ApplicationRecord
  belongs_to :company
  has_many :candidate_taggings, dependent: :destroy
  has_many :candidates, through: :candidate_taggings

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
