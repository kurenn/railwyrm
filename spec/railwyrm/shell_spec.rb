# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe Railwyrm::Shell do
  it "runs commands in unbundled env when Bundler is available" do
    ui = Railwyrm::UI::Buffer.new
    shell = described_class.new(ui: ui, dry_run: false, verbose: false)
    status = instance_double(Process::Status, success?: true)
    wait_thr = instance_double(Thread, value: status)
    stdin = instance_double(IO, close: true)

    allow(Bundler).to receive(:with_unbundled_env).and_yield
    allow(Open3).to receive(:popen2e).and_yield(stdin, StringIO.new(""), wait_thr)

    expect(shell.run!("echo", "ok", chdir: "/tmp")).to be(true)
    expect(Bundler).to have_received(:with_unbundled_env)
    expect(stdin).to have_received(:close)
    expect(Open3).to have_received(:popen2e).with("echo", "ok", chdir: "/tmp")
  end

  it "raises command failed when the command exits non-zero" do
    ui = Railwyrm::UI::Buffer.new
    shell = described_class.new(ui: ui, dry_run: false, verbose: true)
    status = instance_double(Process::Status, success?: false, exitstatus: 2)
    wait_thr = instance_double(Thread, value: status)
    stdin = instance_double(IO, close: true)

    allow(Bundler).to receive(:with_unbundled_env).and_yield
    allow(Open3).to receive(:popen2e).and_yield(stdin, StringIO.new("boom\n"), wait_thr)

    expect { shell.run!("false") }.to raise_error(Railwyrm::CommandFailed) do |error|
      expect(error.message).to include("Command failed with status 2: false")
      expect(error.message).to include("boom")
    end
    expect(stdin).to have_received(:close)
  end
  it "reports both ends of a long failure output" do
    ui = Railwyrm::UI::Buffer.new
    shell = described_class.new(ui: ui, dry_run: false, verbose: false)
    status = instance_double(Process::Status, success?: false, exitstatus: 1)
    wait_thr = instance_double(Thread, value: status)
    stdin = instance_double(IO, close: true)
    output = StringIO.new((1..40).map { |n| "line#{n}" }.join("\n"))

    allow(Bundler).to receive(:with_unbundled_env).and_yield
    allow(Open3).to receive(:popen2e).and_yield(stdin, output, wait_thr)

    expect { shell.run!("noisy") }.to raise_error(Railwyrm::CommandFailed) do |error|
      expect(error.message).to include("line1")
      expect(error.message).to include("line40")
      expect(error.message).to match(/more line/)
    end
  end
end
