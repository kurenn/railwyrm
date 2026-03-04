# frozen_string_literal: true

module Gym
  class MembershipPlansController < BaseController
    before_action :set_plan, only: %i[edit update]

    def index
      authorize MembershipPlan, :index?
      @membership_plans = plan_scope.order(active: :desc, price_cents: :asc)
    end

    def new
      @membership_plan = plan_scope.new(active: true, billing_cycle: "monthly")
      authorize @membership_plan
    end

    def create
      @membership_plan = plan_scope.new(membership_plan_params)
      authorize @membership_plan

      if @membership_plan.save
        redirect_to membership_plans_path, notice: "Membership plan created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @membership_plan
    end

    def update
      authorize @membership_plan

      if @membership_plan.update(membership_plan_params)
        redirect_to membership_plans_path, notice: "Membership plan updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_plan
      @membership_plan = plan_scope.find(params[:id])
    end

    def plan_scope
      MembershipPlan.where(gym_location_id: current_gym_location.id)
    end

    def membership_plan_params
      params.require(:membership_plan).permit(:name, :price_cents, :billing_cycle, :active)
    end
  end
end
