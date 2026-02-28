# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :company
  has_many :memberships, dependent: :destroy

  validates :name, presence: true
end
