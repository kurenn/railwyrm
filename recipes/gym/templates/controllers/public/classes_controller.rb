# frozen_string_literal: true

module Public
  class ClassesController < ApplicationController
    def index
      @class_sessions = if defined?(ClassSession)
        ClassSession.includes(:gym_location).where(status: %i[scheduled full]).upcoming.limit(25)
      else
        []
      end
    end
  end
end
