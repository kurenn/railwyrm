# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :company
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  validates :name, presence: true
end
