require "spec_helper"

describe "Backing up BOSH" do
  let(:output) { StringIO.new }

  before do
    Bosh::Cli::Config.output = output
  end

  def bosh args
    Bosh::Cli::Runner.run(args.split)
  rescue SystemExit
  end

  it "accepts the backup command" do
    bosh "backup"

    output.string.should_not include("Unknown command: backup")
  end
end