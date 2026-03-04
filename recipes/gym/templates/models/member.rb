# frozen_string_literal: true

class Member < ApplicationRecord
  belongs_to :gym_location

  has_many :memberships, dependent: :destroy
  has_many :membership_plans, through: :memberships
  has_many :visits, dependent: :destroy
  has_many :class_bookings, dependent: :destroy
  has_many :class_sessions, through: :class_bookings

  enum :status, {
    lead: 0,
    active: 1,
    paused: 2,
    canceled: 3
  }, default: :active

  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: { scope: :gym_location_id }

  before_validation :normalize_email

  def full_name
    [first_name, last_name].compact.join(" ")
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
