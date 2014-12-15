require 'spec_helper'

describe Bosh::Cli::Command::Deployment do

  let(:director) { double(Bosh::Cli::Client::Director) }
  let(:cmd) { described_class.new(nil, director) }

  before :each do
    cmd.add_option(:non_interactive, true)
    cmd.add_option(:target, 'test')
    cmd.add_option(:username, 'user')
    cmd.add_option(:password, 'pass')
  end

  it 'allows deleting the deployment' do
    expect(director).to receive(:delete_deployment).with('foo', force: false)

    cmd.delete('foo')
  end

  it 'needs confirmation to delete deployment' do
    expect(director).not_to receive(:delete_deployment)
    expect(cmd).to receive(:ask)

    cmd.remove_option(:non_interactive)
    cmd.delete('foo')
  end

  it "lists deployments and doesn't fetch manifest on new director" do
    expect(director).to receive(:list_deployments).
      and_return([{ 'name' => 'foo', 'releases' => [], 'stemcells' => [] }])
    expect(director).not_to receive(:get_deployment)

    cmd.list
  end

  it 'lists deployments and fetches manifest on old director' do
    expect(director).to receive(:list_deployments).and_return([{ 'name' => 'foo' }])
    expect(director).to receive(:get_deployment).with('foo').and_return({})

    cmd.list
  end
end
