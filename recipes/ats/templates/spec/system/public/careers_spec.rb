# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public careers", type: :system do
  it "renders the careers page" do
    driven_by(:rack_test)

    visit careers_path

    expect(page).to have_content("Join our team")
  end
end
