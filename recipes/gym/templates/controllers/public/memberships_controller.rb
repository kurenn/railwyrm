# frozen_string_literal: true

module Public
  class MembershipsController < ApplicationController
    def new
      @membership_plans = available_plans
      @member = Member.new if defined?(Member)
    end

    def create
      unless defined?(Member) && defined?(MembershipPlan)
        redirect_to new_membership_path, alert: "Membership signup is not available yet."
        return
      end

      gym_location = current_gym_location
      member = Member.new(member_params.merge(gym_location: gym_location, status: :lead, joined_on: Date.current))

      if member.save
        maybe_create_membership!(member)
        redirect_to schedule_path, notice: "Thanks! We received your membership request."
      else
        @membership_plans = available_plans
        @member = member
        render :new, status: :unprocessable_entity
      end
    end

    private

    def available_plans
      return [] unless defined?(MembershipPlan)

      MembershipPlan.includes(:gym_location).where(active: true).order(:price_cents)
    end

    def current_gym_location
      GymLocation.order(:id).first || GymLocation.create!(name: "Main Gym", code: "main", timezone: Time.zone.tzinfo.name)
    end

    def member_params
      params.require(:member).permit(
        :first_name,
        :last_name,
        :email,
        :phone,
        :emergency_contact_name,
        :emergency_contact_phone
      )
    end

    def maybe_create_membership!(member)
      plan_id = params[:membership_plan_id].presence
      return unless plan_id

      plan = MembershipPlan.find_by(id: plan_id)
      return unless plan

      Membership.create!(
        member: member,
        membership_plan: plan,
        starts_on: Date.current,
        status: :trial,
        auto_renew: true
      )
    end
  end
end
