# frozen_string_literal: true

class ClassBooking < ApplicationRecord
  belongs_to :class_session
  belongs_to :member

  enum :status, {
    booked: 0,
    attended: 1,
    no_show: 2,
    canceled: 3
  }, default: :booked

  validates :member_id, uniqueness: { scope: :class_session_id }
  validate :member_belongs_to_same_gym_location

  before_validation :set_booked_at

  private

  def set_booked_at
    self.booked_at ||= Time.current if booked?
  end

  def member_belongs_to_same_gym_location
    return if member.blank? || class_session.blank?
    return if member.gym_location_id == class_session.gym_location_id

    errors.add(:member_id, "must belong to the class gym location")
  end
end
