# frozen_string_literal: true

class Offer < ApplicationRecord
  belongs_to :application

  validates :salary, numericality: { allow_nil: true, greater_than: 0 }
end
