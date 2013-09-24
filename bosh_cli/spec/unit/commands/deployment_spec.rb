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
    director.should_receive(:delete_deployment).with('foo', force: false)

    cmd.delete('foo')
  end

  it 'needs confirmation to delete deployment' do
    director.should_not_receive(:delete_deployment)
    cmd.should_receive(:ask)

    cmd.remove_option(:non_interactive)
    cmd.delete('foo')
  end

  it "lists deployments and doesn't fetch manifest on new director" do
    director.should_receive(:list_deployments).
      and_return([{ 'name' => 'foo', 'releases' => [], 'stemcells' => [] }])
    director.should_not_receive(:get_deployment)

    cmd.list
  end

  it 'lists deployments and fetches manifest on old director' do
    director.should_receive(:list_deployments).and_return([{ 'name' => 'foo' }])
    director.should_receive(:get_deployment).with('foo').and_return({})

    cmd.list
  end
end
