# frozen_string_literal: true

module Gym
  class MembersController < BaseController
    before_action :set_member, only: %i[show edit update]

    def index
      authorize Member, :index?

      @query = params[:q].to_s.strip
      @members = member_scope.order(created_at: :desc)
      if @query.present?
        like = "%#{@query.downcase}%"
        @members = @members.where("LOWER(first_name) LIKE :q OR LOWER(last_name) LIKE :q OR LOWER(email) LIKE :q", q: like)
      end
    end

    def show
      authorize @member
      @memberships = @member.memberships.includes(:membership_plan).order(created_at: :desc)
      @recent_visits = @member.visits.order(checked_in_at: :desc).limit(10)
    end

    def new
      @member = member_scope.new(joined_on: Date.current)
      authorize @member
    end

    def create
      @member = member_scope.new(member_params)
      authorize @member

      if @member.save
        redirect_to member_path(@member), notice: "Member created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @member
    end

    def update
      authorize @member

      if @member.update(member_params)
        redirect_to member_path(@member), notice: "Member updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_member
      @member = member_scope.find(params[:id])
    end

    def member_scope
      Member.where(gym_location_id: current_gym_location.id)
    end

    def member_params
      params.require(:member).permit(
        :first_name,
        :last_name,
        :email,
        :phone,
        :status,
        :emergency_contact_name,
        :emergency_contact_phone,
        :joined_on
      )
    end
  end
end
