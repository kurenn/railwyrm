# frozen_string_literal: true

class Application < ApplicationRecord
  belongs_to :candidate
  belongs_to :job_posting
  belongs_to :pipeline_stage
  belongs_to :owner, polymorphic: true, optional: true

  has_many :application_events, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :offers, dependent: :destroy

  enum :status, {
    applied: 0,
    screening: 1,
    interview: 2,
    offer: 3,
    hired: 4,
    rejected: 5
  }, default: :applied
end
