# frozen_string_literal: true

class HardenGymConstraints < ActiveRecord::Migration[7.1]
  def change
    add_index :gym_locations, :code, unique: true unless index_exists?(:gym_locations, :code, unique: true)
    add_index :members, [:gym_location_id, :email], unique: true unless index_exists?(:members, [:gym_location_id, :email], unique: true)
    add_index :class_bookings, [:class_session_id, :member_id], unique: true unless index_exists?(:class_bookings, [:class_session_id, :member_id], unique: true)

    change_column_null :gym_locations, :name, false
    change_column_null :gym_locations, :code, false
    change_column_null :gym_locations, :timezone, false

    change_column_null :members, :gym_location_id, false
    change_column_null :members, :first_name, false
    change_column_null :members, :last_name, false
    change_column_null :members, :email, false

    change_column_null :membership_plans, :gym_location_id, false
    change_column_null :membership_plans, :name, false
    change_column_null :membership_plans, :price_cents, false
    change_column_default :membership_plans, :active, from: nil, to: true
    change_column_null :membership_plans, :active, false

    change_column_null :visits, :member_id, false
    change_column_null :visits, :gym_location_id, false
    change_column_null :visits, :checked_in_at, false

    change_column_null :class_sessions, :gym_location_id, false
    change_column_null :class_sessions, :title, false
    change_column_null :class_sessions, :instructor_name, false
    change_column_null :class_sessions, :starts_at, false
    change_column_null :class_sessions, :ends_at, false
    change_column_null :class_sessions, :capacity, false

    change_column_null :class_bookings, :class_session_id, false
    change_column_null :class_bookings, :member_id, false
  end
end
