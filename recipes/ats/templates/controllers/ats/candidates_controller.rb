# frozen_string_literal: true

module Ats
  class CandidatesController < ApplicationController
    before_action :authenticate_user!

    def index
      @candidates = defined?(Candidate) ? Candidate.order(created_at: :desc).limit(50) : []
    end

    def show
      @candidate = defined?(Candidate) ? Candidate.find(params[:id]) : nil
      head :not_found unless @candidate
    end
  end
end
