# frozen_string_literal: true

class ClassSession < ApplicationRecord
  belongs_to :gym_location
  has_many :class_bookings, dependent: :destroy
  has_many :members, through: :class_bookings

  enum :status, {
    scheduled: 0,
    full: 1,
    completed: 2,
    canceled: 3
  }, default: :scheduled

  validates :title, :instructor_name, :starts_at, :ends_at, :capacity, presence: true
  validates :capacity, numericality: { greater_than: 0 }
  validate :ends_at_after_starts_at

  scope :upcoming, -> { where(starts_at: Time.current..).order(:starts_at) }

  def booked_count
    class_bookings.where.not(status: :canceled).count
  end

  def spots_left
    [capacity.to_i - booked_count, 0].max
  end

  def full?
    spots_left.zero?
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "must be after starts_at")
  end
end
