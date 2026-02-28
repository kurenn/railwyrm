# frozen_string_literal: true

module Ats
  class PipelineBoardController < ApplicationController
    before_action :authenticate_user!

    def show
      @applications = defined?(Application) ? Application.limit(100) : []
    end
  end
end
