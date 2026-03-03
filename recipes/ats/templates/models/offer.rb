# frozen_string_literal: true

class Offer < ApplicationRecord
  STATUSES = %w[draft sent accepted declined].freeze

  belongs_to :application

  validates :salary, numericality: { allow_nil: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }, allow_blank: true
end
