# frozen_string_literal: true

class Visit < ApplicationRecord
  belongs_to :member
  belongs_to :gym_location

  validates :checked_in_at, presence: true
  validate :checked_out_at_after_checked_in_at

  before_validation :assign_gym_location_from_member

  private

  def assign_gym_location_from_member
    self.gym_location ||= member&.gym_location
  end

  def checked_out_at_after_checked_in_at
    return if checked_out_at.blank? || checked_in_at.blank?
    return if checked_out_at >= checked_in_at

    errors.add(:checked_out_at, "must be after checked_in_at")
  end
end
