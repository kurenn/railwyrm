# frozen_string_literal: true

require "spec_helper"

RSpec.describe Railwyrm::Configuration do
  it "defaults sign_in_layout to card_combined" do
    config = described_class.new(name: "demo_app", workspace: "/tmp")

    expect(config.sign_in_layout).to eq("card_combined")
    expect(config.devise_confirmable?).to be(false)
    expect(config.devise_lockable?).to be(false)
    expect(config.devise_timeoutable?).to be(false)
    expect(config.devise_trackable?).to be(false)
    expect(config.devise_magic_link?).to be(false)
  end

  it "accepts each supported sign_in_layout" do
    described_class::SIGN_IN_LAYOUTS.each do |layout|
      config = described_class.new(name: "demo_app", workspace: "/tmp", sign_in_layout: layout)
      expect(config.sign_in_layout).to eq(layout)
    end
  end

  it "raises on unsupported sign_in_layout" do
    expect do
      described_class.new(name: "demo_app", workspace: "/tmp", sign_in_layout: "unknown")
    end.to raise_error(Railwyrm::InvalidConfiguration, /Sign-in layout/)
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
end
