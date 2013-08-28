require 'spec_helper'

describe VSphereCloud::Cloud do
  let(:client_stub) { double(cookie: nil) }
  let(:client) { instance_double('VSphereCloud::Client', login: nil, logout: nil, stub: client_stub) }
  let(:config) { { fake: 'config' } }

  subject { VSphereCloud::Cloud.new(config) }

  before do
    VSphereCloud::Config.should_receive(:configure).with(config)
    VSphereCloud::Cloud.any_instance.stub(:at_exit)
    VSphereCloud::Client.stub(new: client)
  end

  describe '#create_vm' do
    let(:logger) { double('Logger') }
    let(:resources) { double('Resources') }
    let(:client) { double('Client') }
    let(:agent_id) { '007' }
    let(:stemcell) { 'sc-id' }
    let(:resource_pool) { { 'ram' => 2048, 'disk' => 2048, 'cpu' => 1 } }
    let(:networks) { { 'my-network' => nil } }
    let(:disk_locality) { 'Disk Locality' }
    let(:environment) { 'Environment' }
    let(:vm_creator) { instance_double('VSphereCloud::VMCreator') }

    before do
      VSphereCloud::Resources.stub(new: resources)
      VSphereCloud::Config.stub(logger: logger)
      VSphereCloud::Config.stub(client: client)
    end

    it 'delegates to VMCreator' do
      VSphereCloud::VMCreator.should_receive(:new).with(agent_id: agent_id,
                                          stemcell: stemcell,
                                          resource_pool: resource_pool,
                                          networks: networks,
                                          disk_locality: disk_locality,
                                          environment: environment,
                                          resources: resources,
                                          client: client,
                                          logger: logger,
                                          vsphere_cloud: subject,
      ).and_return(vm_creator)
      vm_creator.should_receive(:perform).and_return('vm-id')

      subject.create_vm(agent_id, stemcell, resource_pool, networks, disk_locality, environment)
    end
  end

  describe 'has_vm?' do
    let(:vm_id) { 'vm_id' }

    context 'the vm is found' do
      it 'returns true' do
        subject.should_receive(:get_vm_by_cid).with(vm_id)
        expect(subject.has_vm?(vm_id)).to be_true
      end
    end

    context 'the vm is not found' do
      it 'returns false' do
        subject.should_receive(:get_vm_by_cid).with(vm_id).and_raise(Bosh::Clouds::VMNotFound)
        expect(subject.has_vm?(vm_id)).to be_false
      end
    end
  end

  describe 'snapshot_disk' do
    it 'raises not implemented exception when called' do
      expect { subject.snapshot_disk('123') }.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end
end
