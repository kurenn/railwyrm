# frozen_string_literal: true

module Users
  class PasskeysController < Devise::PasskeysController
    rescue_from JSON::ParserError, with: :handle_invalid_payload

    private

    def handle_invalid_payload
      flash[:alert] = "__PASSKEYS_SUPPORT_NOTE__"
      redirect_to new_passkey_path(resource_name)
    end
  end
end
