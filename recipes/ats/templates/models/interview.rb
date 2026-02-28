# frozen_string_literal: true

class Interview < ApplicationRecord
  belongs_to :application
  belongs_to :interviewer, polymorphic: true, optional: true

  has_many :feedbacks, dependent: :destroy

  enum :kind, {
    phone_screen: 0,
    technical: 1,
    hiring_manager: 2,
    final_round: 3,
    culture: 4
  }, default: :phone_screen

  validates :starts_at, presence: true
end
