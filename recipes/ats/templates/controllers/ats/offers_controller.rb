# frozen_string_literal: true

module Ats
  class OffersController < BaseController
    before_action :set_application
    before_action :set_offer, only: %i[update]

    def create
      offer = @application.offers.new(offer_params)
      authorize offer

      if offer.save
        @application.update(status: :offer)
        redirect_to application_path(@application), notice: "Offer created."
      else
        redirect_to application_path(@application), alert: offer.errors.full_messages.to_sentence
      end
    end

    def update
      authorize @offer

      if @offer.update(offer_params)
        @application.update(status: :hired) if @offer.status == "accepted"
        redirect_to application_path(@application), notice: "Offer updated."
      else
        redirect_to application_path(@application), alert: @offer.errors.full_messages.to_sentence
      end
    end

    private

    def set_application
      @application = Application.find(params[:application_id])
    end

    def set_offer
      @offer = @application.offers.find(params[:id])
    end

    def offer_params
      params.require(:offer).permit(:salary, :equity, :starts_on, :status, :sent_at, :responded_at)
    end
  end
end
