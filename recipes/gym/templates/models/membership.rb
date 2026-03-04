# frozen_string_literal: true

class Membership < ApplicationRecord
  belongs_to :member
  belongs_to :membership_plan

  enum :status, {
    trial: 0,
    active: 1,
    overdue: 2,
    canceled: 3
  }, default: :active

  validates :starts_on, presence: true
  validate :ends_on_not_before_starts_on

  def gym_location
    membership_plan&.gym_location
  end

  private

  def ends_on_not_before_starts_on
    return if ends_on.blank? || starts_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, "must be on or after starts_on")
  end
end
