# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::FeatureDetector do
  it "detects installed features from model/routes/gemfile" do
    Dir.mktmpdir do |app_path|
      File.write(
        File.join(app_path, "Gemfile"),
        <<~RUBY
          source "https://rubygems.org"
          gem "devise-passwordless"
        RUBY
      )

      FileUtils.mkdir_p(File.join(app_path, "app/models"))
      File.write(
        File.join(app_path, "app/models/user.rb"),
        <<~RUBY
          class User < ApplicationRecord
            devise :trackable, :magic_link_authenticatable, :confirmable
          end
        RUBY
      )

      FileUtils.mkdir_p(File.join(app_path, "config"))
      File.write(
        File.join(app_path, "config/routes.rb"),
        <<~RUBY
          Rails.application.routes.draw do
            namespace :passwordless do
              devise_for :users, controllers: { sessions: "devise/passwordless/sessions" }
            end
          end
        RUBY
      )

      detector = described_class.new(app_path: app_path, devise_user_model: "User")
      expect(detector.detect).to eq(%w[confirmable trackable magic_link])
    end
  end
end
