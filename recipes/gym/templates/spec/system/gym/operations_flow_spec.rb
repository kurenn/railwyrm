# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Gym operations flow", type: :system do
  it "creates member and records visit" do
    driven_by(:rack_test)

    user = create_authenticated_user(email: "manager.flow@test.local", role: :manager)
    ensure_base_location!

    login_as user, scope: :user

    visit new_member_path
    fill_in "First name", with: "Mila"
    fill_in "Last name", with: "Stone"
    fill_in "Email", with: "mila.stone@test.local"
    fill_in "Phone", with: "+1-555-2222"
    click_button "Create member"

    expect(page).to have_content("Member created")
    expect(page).to have_content("Mila Stone")

    visit visits_path
    click_button "Check in Mila Stone"

    expect(page).to have_content("Visit recorded")
  end
end
