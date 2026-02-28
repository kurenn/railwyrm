# frozen_string_literal: true

class CandidateTagging < ApplicationRecord
  belongs_to :candidate
  belongs_to :candidate_tag

  validates :candidate_id, uniqueness: { scope: :candidate_tag_id }
end
