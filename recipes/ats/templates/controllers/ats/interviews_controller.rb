# frozen_string_literal: true

module Ats
  class InterviewsController < ApplicationController
    before_action :authenticate_user!

    def create
      head :not_implemented
    end

    def update
      head :not_implemented
    end

    def destroy
      head :not_implemented
    end
  end
end
