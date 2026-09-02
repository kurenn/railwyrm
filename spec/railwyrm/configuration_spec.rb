# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::Configuration do
  it "uses sane defaults for optional Devise modules" do
    config = described_class.new(name: "demo_app", workspace: "/tmp")

    expect(config.devise_confirmable?).to be(false)
    expect(config.devise_lockable?).to be(false)
    expect(config.devise_timeoutable?).to be(false)
    expect(config.devise_trackable?).to be(false)
    expect(config.devise_magic_link?).to be(false)
    expect(config.devise_passkeys?).to be(false)
    expect(config.claude_marketplace?).to be(false)
  end

  it "exposes claude_marketplace when enabled" do
    config = described_class.new(name: "demo_app", workspace: "/tmp", claude_marketplace: true)

    expect(config.claude_marketplace?).to be(true)
    expect(config.to_h).to include(claude_marketplace: true)
  end

  it "raises when confirmable is enabled while devise user generation is disabled" do
    expect do
      described_class.new(
        name: "demo_app",
        workspace: "/tmp",
        install_devise_user: false,
        devise_confirmable: true
      )
    end.to raise_error(Railwyrm::InvalidConfiguration, /confirmable requires generating a Devise user model/)
  end

  it "raises when lockable is enabled while devise user generation is disabled" do
    expect do
      described_class.new(
        name: "demo_app",
        workspace: "/tmp",
        install_devise_user: false,
        devise_lockable: true
      )
    end.to raise_error(Railwyrm::InvalidConfiguration, /lockable requires generating a Devise user model/)
  end

  it "raises when timeoutable is enabled while devise user generation is disabled" do
    expect do
      described_class.new(
        name: "demo_app",
        workspace: "/tmp",
        install_devise_user: false,
        devise_timeoutable: true
      )
    end.to raise_error(Railwyrm::InvalidConfiguration, /timeoutable requires generating a Devise user model/)
  end

  it "raises when magic link is enabled while devise user generation is disabled" do
    expect do
      described_class.new(
        name: "demo_app",
        workspace: "/tmp",
        install_devise_user: false,
        devise_magic_link: true
      )
    end.to raise_error(Railwyrm::InvalidConfiguration, /magic link requires generating a Devise user model/)
  end

  it "raises when trackable is enabled while devise user generation is disabled" do
    expect do
      described_class.new(
        name: "demo_app",
        workspace: "/tmp",
        install_devise_user: false,
        devise_trackable: true
      )
    end.to raise_error(Railwyrm::InvalidConfiguration, /trackable requires generating a Devise user model/)
  end

  it "raises when passkeys is enabled while devise user generation is disabled" do
    expect do
      described_class.new(
        name: "demo_app",
        workspace: "/tmp",
        install_devise_user: false,
        devise_passkeys: true
      )
    end.to raise_error(Railwyrm::InvalidConfiguration, /passkeys requires generating a Devise user model/)
  end

  it "forces trackable when magic link is enabled" do
    config = described_class.new(
      name: "demo_app",
      workspace: "/tmp",
      devise_trackable: false,
      devise_magic_link: true
    )

    expect(config.devise_magic_link?).to be(true)
    expect(config.devise_trackable?).to be(true)
  end
  it "rejects a rails version that is not a version" do
    expect do
      described_class.new(name: "demo_app", workspace: "/tmp", rails_version: "edge")
    end.to raise_error(Railwyrm::InvalidConfiguration, /Rails version must look like/)
  end

  it "treats a blank rails version as unset" do
    config = described_class.new(name: "demo_app", workspace: "/tmp", rails_version: "  ")

    expect(config.rails_version).to be_nil
  end
end
