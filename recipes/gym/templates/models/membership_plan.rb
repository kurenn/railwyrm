# frozen_string_literal: true

class MembershipPlan < ApplicationRecord
  belongs_to :gym_location
  has_many :memberships, dependent: :restrict_with_error

  validates :name, :billing_cycle, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  def price
    price_cents.to_i / 100.0
  end
end
