# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::AppPatcher do
  def patcher_for(app_path, ui)
    described_class.new(app_path: app_path, ui: ui, shell: nil, devise_user_model: "User")
  end

  def warnings(ui)
    ui.logs.select { |entry| entry[:level] == "warn" }.map { |entry| entry[:message] }
  end

  it "warns instead of silently skipping when a target file is missing" do
    Dir.mktmpdir do |app_path|
      ui = Railwyrm::UI::Buffer.new
      patcher = patcher_for(app_path, ui)

      patcher.normalize_application_main_layout!
      patcher.ensure_devise_initializer_lint_defaults!
      patcher.ensure_bullet_development_configuration!
      patcher.send(:ensure_devise_paranoid_mode!)
      patcher.send(:ensure_development_mail_file_delivery!)
      patcher.send(:ensure_webauthn_initializer_defaults!)
      patcher.send(:ensure_webauthn_javascript_include!)
      patcher.send(:ensure_passkey_enrollment_redirect!)

      expect(warnings(ui).length).to eq(8)
      expect(warnings(ui)).to all(match(/not found; skipped/))
    end
  end

  it "warns when the layout has no main element to normalize" do
    Dir.mktmpdir do |app_path|
      FileUtils.mkdir_p(File.join(app_path, "app/views/layouts"))
      File.write(
        File.join(app_path, "app/views/layouts/application.html.erb"),
        "<html><body><%= yield %></body></html>\n"
      )
      ui = Railwyrm::UI::Buffer.new

      patcher_for(app_path, ui).normalize_application_main_layout!

      expect(warnings(ui)).to include(match(/no <main> element/))
    end
  end

  it "warns when the layout has nowhere to put the WebAuthn javascript" do
    Dir.mktmpdir do |app_path|
      FileUtils.mkdir_p(File.join(app_path, "app/views/layouts"))
      File.write(
        File.join(app_path, "app/views/layouts/application.html.erb"),
        "<main><%= yield %></main>\n"
      )
      ui = Railwyrm::UI::Buffer.new

      patcher_for(app_path, ui).send(:ensure_webauthn_javascript_include!)

      expect(warnings(ui)).to include(match(/no stylesheet tag or <\/head>/))
    end
  end

  it "still patches a layout that does have a main element" do
    Dir.mktmpdir do |app_path|
      layout_path = File.join(app_path, "app/views/layouts/application.html.erb")
      FileUtils.mkdir_p(File.dirname(layout_path))
      File.write(layout_path, "<main class=\"container\"><%= yield %></main>\n")
      ui = Railwyrm::UI::Buffer.new

      patcher_for(app_path, ui).normalize_application_main_layout!

      expect(File.read(layout_path)).to include("min-h-screen")
      expect(warnings(ui)).to be_empty
    end
  end
end
