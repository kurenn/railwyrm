# frozen_string_literal: true

module Ats
  class ReportsController < ApplicationController
    before_action :authenticate_user!

    def index
      @applications_by_status = if defined?(Application)
                                  Application.group(:status).count
                                else
                                  {}
                                end
    end
  end
end
