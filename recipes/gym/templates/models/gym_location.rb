# frozen_string_literal: true

class GymLocation < ApplicationRecord
  has_many :membership_plans, dependent: :destroy
  has_many :members, dependent: :destroy
  has_many :visits, dependent: :destroy
  has_many :class_sessions, dependent: :destroy

  validates :name, :code, :timezone, presence: true
  validates :code, uniqueness: true

  before_validation :normalize_code

  private

  def normalize_code
    return if code.blank?

    self.code = code.to_s.parameterize(separator: "_")
  end
end
