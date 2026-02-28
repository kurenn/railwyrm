# frozen_string_literal: true

class PipelineStage < ApplicationRecord
  belongs_to :job_posting
  has_many :applications, dependent: :nullify

  validates :name, presence: true
  validates :position, presence: true, uniqueness: { scope: :job_posting_id }
end
