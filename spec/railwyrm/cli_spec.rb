# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::CLI do
  it "lists installable features" do
    expect { described_class.start(["feature", "list"]) }
      .to output(/Installable features.*magic_link/m).to_stdout
  end

  it "installs features into an existing app via feature command" do
    Dir.mktmpdir do |app_path|
      installer = instance_double(Railwyrm::FeatureInstaller, install!: %w[trackable magic_link])
      allow(Railwyrm::FeatureInstaller).to receive(:new).and_return(installer)

      expect do
        described_class.start(
          [
            "feature",
            "install",
            "magic_link",
            "--app",
            app_path
          ]
        )
      end.not_to raise_error

      expect(Railwyrm::FeatureInstaller).to have_received(:new).with(
        hash_including(app_path: app_path, devise_user_model: "User", dry_run: false)
      )
      expect(installer).to have_received(:install!).with(["magic_link"])
    end
  end

  it "shows feature status for an existing app via feature command" do
    status_service = instance_double(
      Railwyrm::FeatureStatus,
      snapshot: {
        app_path: "/tmp/demo_app",
        manifest_path: "/tmp/demo_app/.railwyrm/features.yml",
        installed: ["trackable"],
        tracked_only: ["confirmable"],
        detected_only: [],
        available: %w[confirmable lockable timeoutable trackable magic_link]
      }
    )
    allow(Railwyrm::FeatureStatus).to receive(:new).and_return(status_service)

    expect do
      described_class.start(["feature", "status", "--app", "/tmp/demo_app"])
    end.to output(/Feature status.*installed: trackable.*tracked_only: confirmable/m).to_stdout

    expect(Railwyrm::FeatureStatus).to have_received(:new).with(
      hash_including(app_path: "/tmp/demo_app", devise_user_model: "User")
    )
  end

  it "requires APP_NAME when non-interactive" do
    Dir.mktmpdir do |workspace|
      expect do
        described_class.start(["new", "--interactive=false", "--path", workspace, "--no-banner"])
      end.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    end
  end

  it "passes devise confirmable option in non-interactive new flow" do
    Dir.mktmpdir do |workspace|
      app_name = "confirmable_cli_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)

      expect(Railwyrm::Generator).to receive(:new) do |config, ui:|
        expect(config.devise_confirmable?).to be(true)
        expect(config.devise_lockable?).to be(false)
        expect(config.devise_timeoutable?).to be(false)
        expect(config.devise_trackable?).to be(false)
        expect(config.devise_magic_link?).to be(false)
        expect(config.install_devise_user?).to be(true)
        expect(ui).to be_a(Railwyrm::UI::Console)
        generator
      end

      expect do
        described_class.start(
          [
            "new",
            app_name,
            "--interactive=false",
            "--path",
            workspace,
            "--devise_confirmable=true",
            "--no-banner"
          ]
        )
      end.not_to raise_error
    end
  end

  it "passes devise lockable and timeoutable options in non-interactive new flow" do
    Dir.mktmpdir do |workspace|
      app_name = "lockable_timeoutable_cli_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)

      expect(Railwyrm::Generator).to receive(:new) do |config, ui:|
        expect(config.devise_confirmable?).to be(false)
        expect(config.devise_lockable?).to be(true)
        expect(config.devise_timeoutable?).to be(true)
        expect(config.devise_trackable?).to be(false)
        expect(config.devise_magic_link?).to be(false)
        expect(config.install_devise_user?).to be(true)
        expect(ui).to be_a(Railwyrm::UI::Console)
        generator
      end

      expect do
        described_class.start(
          [
            "new",
            app_name,
            "--interactive=false",
            "--path",
            workspace,
            "--devise_lockable=true",
            "--devise_timeoutable=true",
            "--no-banner"
          ]
        )
      end.not_to raise_error
    end
  end

  it "passes devise trackable option in non-interactive new flow" do
    Dir.mktmpdir do |workspace|
      app_name = "trackable_cli_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)

      expect(Railwyrm::Generator).to receive(:new) do |config, ui:|
        expect(config.devise_trackable?).to be(true)
        expect(config.devise_magic_link?).to be(false)
        expect(ui).to be_a(Railwyrm::UI::Console)
        generator
      end

      expect do
        described_class.start(
          [
            "new",
            app_name,
            "--interactive=false",
            "--path",
            workspace,
            "--devise_trackable=true",
            "--no-banner"
          ]
        )
      end.not_to raise_error
    end
  end

  it "auto-enables trackable when magic-link is enabled" do
    Dir.mktmpdir do |workspace|
      app_name = "magic_link_cli_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)

      expect(Railwyrm::Generator).to receive(:new) do |config, ui:|
        expect(config.devise_magic_link?).to be(true)
        expect(config.devise_trackable?).to be(true)
        expect(ui).to be_a(Railwyrm::UI::Console)
        generator
      end

      expect do
        described_class.start(
          [
            "new",
            app_name,
            "--interactive=false",
            "--path",
            workspace,
            "--devise_magic_link=true",
            "--devise_trackable=false",
            "--no-banner"
          ]
        )
      end.not_to raise_error
    end
  end

  it "asks for supported devise modules in interactive flow" do
    Dir.mktmpdir do |workspace|
      app_name = "wizard_app"
      app_path = File.join(workspace, app_name)
      generator = instance_double(Railwyrm::Generator, run!: app_path)
      prompt = instance_double(TTY::Prompt)

      expect(Railwyrm::Generator).to receive(:new) do |config, ui:|
        expect(config.devise_confirmable?).to be(true)
        expect(config.devise_lockable?).to be(false)
        expect(config.devise_timeoutable?).to be(true)
        expect(config.devise_trackable?).to be(true)
        expect(config.devise_magic_link?).to be(false)
        expect(config.sign_in_layout).to eq("card_combined")
        expect(ui).to be_a(Railwyrm::UI::Console)
        generator
      end

      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive(:ask) do |question, **_kwargs|
        if question.include?("App name")
          app_name
        elsif question.include?("Workspace path")
          workspace
        else
          "User"
        end
      end
      expect(prompt).to receive(:yes?).with("🔐 Generate Devise user model now?", default: true).and_return(true)
      expect(prompt).to receive(:yes?)
        .with("✉️ Enable Devise confirmable (email confirmation required)?", default: false)
        .and_return(true)
      expect(prompt).to receive(:yes?)
        .with("🔒 Enable Devise lockable (lock account after failed attempts)?", default: false)
        .and_return(false)
      expect(prompt).to receive(:yes?)
        .with("⏱️ Enable Devise timeoutable (auto sign out inactive users)?", default: false)
        .and_return(true)
      expect(prompt).to receive(:yes?)
        .with("📈 Enable Devise trackable (track sign in count, timestamps, and IPs)?", default: false)
        .and_return(true)
      expect(prompt).to receive(:yes?)
        .with("✨ Enable magic-link sign-in by email?", default: false)
        .and_return(false)
      expect(prompt).to receive(:select)
        .with("🧩 Select sign-in layout:", default: "Card Combined (recommended)")
        .and_return("card_combined")

      expect { described_class.start(["new", app_name, "--path", workspace, "--no-banner"]) }.not_to raise_error
    end
  end
end
