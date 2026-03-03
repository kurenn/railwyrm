# frozen_string_literal: true

module Ats
  class BaseController < ApplicationController
    include Pundit::Authorization
    include Ats::CurrentContext

    before_action :authenticate_user!
    before_action :set_current_actor
    after_action :clear_current_actor

    rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized

    private

    def set_current_actor
      Current.user = current_user if defined?(Current)
    end

    def clear_current_actor
      Current.reset if defined?(Current)
    end

    def handle_not_authorized
      redirect_back fallback_location: authenticated_root_path, alert: "You do not have permission for this action."
    end
  end
end
