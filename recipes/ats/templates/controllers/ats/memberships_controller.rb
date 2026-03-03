# frozen_string_literal: true

module Ats
  class MembershipsController < BaseController
    before_action :set_team
    before_action :set_membership, only: %i[update destroy]

    def create
      membership = @team.memberships.new(membership_params)
      authorize membership

      if membership.save
        redirect_to team_path(@team), notice: "Member added."
      else
        redirect_to team_path(@team), alert: membership.errors.full_messages.to_sentence
      end
    end

    def update
      authorize @membership

      if @membership.update(membership_params)
        redirect_to team_path(@team), notice: "Membership updated."
      else
        redirect_to team_path(@team), alert: @membership.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @membership
      @membership.destroy

      redirect_to team_path(@team), notice: "Membership removed."
    end

    private

    def set_team
      @team = Team.find(params[:team_id])
    end

    def set_membership
      @membership = @team.memberships.find(params[:id])
    end

    def membership_params
      params.require(:membership).permit(:user_id, :role)
    end
  end
end
