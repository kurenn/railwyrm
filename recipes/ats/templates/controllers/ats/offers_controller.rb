# frozen_string_literal: true

module Ats
  class OffersController < ApplicationController
    before_action :authenticate_user!

    def create
      head :not_implemented
    end

    def update
      head :not_implemented
    end
  end
end
