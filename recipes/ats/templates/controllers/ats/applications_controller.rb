# frozen_string_literal: true

module Ats
  class ApplicationsController < ApplicationController
    before_action :authenticate_user!

    def index
      @applications = defined?(Application) ? Application.order(created_at: :desc).limit(50) : []
    end

    def show
      @application = defined?(Application) ? Application.find(params[:id]) : nil
      head :not_found unless @application
    end

    def create
      head :not_implemented
    end

    def update
      head :not_implemented
    end
  end
end
