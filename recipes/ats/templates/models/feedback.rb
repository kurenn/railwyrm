# frozen_string_literal: true

class Feedback < ApplicationRecord
  belongs_to :interview
  belongs_to :reviewer, polymorphic: true, optional: true

  validates :score, numericality: { allow_nil: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
end
