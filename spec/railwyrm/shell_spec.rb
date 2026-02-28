# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe Railwyrm::Shell do
  it "runs commands in unbundled env when Bundler is available" do
    ui = Railwyrm::UI::Buffer.new
    shell = described_class.new(ui: ui, dry_run: false, verbose: false)
    status = instance_double(Process::Status, success?: true)
    wait_thr = instance_double(Thread, value: status)

    allow(Bundler).to receive(:with_unbundled_env).and_yield
    allow(Open3).to receive(:popen2e).and_yield(nil, StringIO.new(""), wait_thr)

    expect(shell.run!("echo", "ok", chdir: "/tmp")).to be(true)
    expect(Bundler).to have_received(:with_unbundled_env)
    expect(Open3).to have_received(:popen2e).with("echo", "ok", chdir: "/tmp")
  end

  it "raises command failed when the command exits non-zero" do
    ui = Railwyrm::UI::Buffer.new
    shell = described_class.new(ui: ui, dry_run: false, verbose: true)
    status = instance_double(Process::Status, success?: false, exitstatus: 2)
    wait_thr = instance_double(Thread, value: status)

    allow(Bundler).to receive(:with_unbundled_env).and_yield
    allow(Open3).to receive(:popen2e).and_yield(nil, StringIO.new("boom\n"), wait_thr)

    expect { shell.run!("false") }
      .to raise_error(Railwyrm::CommandFailed, /Command failed with status 2: false/)
  end
end
