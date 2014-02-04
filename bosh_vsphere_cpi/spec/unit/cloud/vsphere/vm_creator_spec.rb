require 'spec_helper'
require 'cloud/vsphere/vm_creator'

describe VSphereCloud::VmCreator do
  describe '#create' do
    let(:placer) { double('placer') }
    let(:vsphere_client) { instance_double('VSphereCloud::Client') }
    let(:logger) { double('logger') }
    let(:cpi) { instance_double('VSphereCloud::Cloud') }
    subject(:creator) { described_class.new(placer, vsphere_client, logger, cpi) }

    context 'when the number of cpu is not a power of 2' do
      it 'raises an error  to work around a vCenter bug' do
        expect {
          creator.create(nil, nil, { 'cpu' => 3 }, nil, [], {})
        }.to raise_error('Number of vCPUs: 3 is not a power of 2.')
      end
    end

    context 'when the stemcell vm does not exist' do
      before do
        allow(cpi).to receive(:stemcell_vm).with('sc-beef').and_return(nil)
      end
      it 'raises an error' do
        expect {
          creator.create(nil, 'sc-beef', { 'cpu' => 1 }, nil, [], nil)
        }.to raise_error('Could not find stemcell: sc-beef')
      end
    end
  end
end
