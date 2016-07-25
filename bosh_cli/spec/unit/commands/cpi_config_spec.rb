require 'spec_helper'

describe Bosh::Cli::Command::CpiConfig do
  let(:director) { double(Bosh::Cli::Client::Director) }
  let(:runner) { instance_double('Bosh::Cli::Runner') }
  subject(:cpi_config_command) { described_class.new(nil, director) }
  let(:actual) { Bosh::Cli::Config.output.string }
  let(:valid_cpi_manifest) { Psych.dump(Bosh::Spec::Deployments.simple_cpi_config) }

  before { @config = Support::TestConfig.new(cpi_config_command) }
  after { @config.clean }

  before :each do
    target = 'https://127.0.0.1:8080'

    config = @config.load
    config.target = target
    config.set_alias('target', 'alpha', 'http://127.0.0.1:8080')

    config.save

    cpi_config_command.add_option(:non_interactive, true)
    cpi_config_command.add_option(:target, target)
    cpi_config_command.add_option(:username, 'user')
    cpi_config_command.add_option(:password, 'pass')

    stub_request(:get, "#{target}/info").to_return(body: '{}')
  end

  before(:each) do
    allow(cpi_config_command).to receive(:runner).and_return(runner)
    allow(runner).to receive(:usage).and_return('fake runner usage')
  end

  it "show outputs latest cpi config" do
    expect(director).to receive(:get_cpi_config)
    cpi_config_command.show
  end

  it "shows success when successfully updating cpi config" do
    allow(cpi_config_command).to receive(:read_yaml_file).and_return("something")
    expect(director).to receive(:update_cpi_config).with("something").and_return(true)
    expect(cpi_config_command).to receive(:say).with("Successfully updated cpi config")
    cpi_config_command.update("/path/to/alpha.yml")
  end

  it "shows error when failing to update cpi config" do
    allow(cpi_config_command).to receive(:read_yaml_file).and_return("something")
    expect(director).to receive(:update_cpi_config).with("something").and_return(false)
    expect{cpi_config_command.update("/path/to/alpha.yml")}.to raise_error(Bosh::Cli::CliError, "Failed to update cpi config")
  end
end