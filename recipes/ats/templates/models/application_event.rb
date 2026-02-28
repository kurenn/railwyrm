# frozen_string_literal: true

class ApplicationEvent < ApplicationRecord
  belongs_to :application
  belongs_to :actor, polymorphic: true, optional: true

  validates :event_type, :occurred_at, presence: true
end
