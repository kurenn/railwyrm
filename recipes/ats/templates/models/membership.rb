# frozen_string_literal: true

class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :team

  enum :role, {
    admin: 0,
    recruiter: 1,
    hiring_manager: 2,
    interviewer: 3
  }, default: :recruiter

  validates :user_id, uniqueness: { scope: :team_id }
end
