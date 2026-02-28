# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public careers", type: :request do
  it "renders the careers index" do
    get careers_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Join our team")
  end
end
