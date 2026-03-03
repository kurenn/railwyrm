# frozen_string_literal: true

module Ats
  class TeamsController < BaseController
    before_action :set_team, only: %i[show edit update]

    def index
      authorize Team
      @teams = Team.includes(:company, memberships: :user).order(:name)
    end

    def show
      authorize @team
      @memberships = @team.memberships.includes(:user).order(:created_at)
      @users = User.order(:email)
    end

    def new
      @team = Team.new
      authorize @team
    end

    def create
      @team = Team.new(team_params)
      @team.company ||= current_company || Company.first
      authorize @team

      if @team.save
        redirect_to team_path(@team), notice: "Team created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @team
    end

    def update
      authorize @team

      if @team.update(team_params)
        redirect_to team_path(@team), notice: "Team updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_team
      @team = Team.find(params[:id])
    end

    def team_params
      params.require(:team).permit(:name)
    end
  end
end
