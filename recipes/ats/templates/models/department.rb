# frozen_string_literal: true

class Department < ApplicationRecord
  belongs_to :company
  has_many :job_postings, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
