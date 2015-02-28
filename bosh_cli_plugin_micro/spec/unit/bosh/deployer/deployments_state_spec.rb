require 'spec_helper'
require 'bosh/deployer/deployments_state'
require 'logger'

require 'bosh/deployer/instance_manager/vsphere'

module Bosh::Deployer
  describe DeploymentsState do
    let(:deployments_file) { 'fake-dir/bosh-deployments.yml' }

    describe '.load_from_dir' do
      let(:fake_deployments_state) { double('DeploymentsState') }
      let(:logger) { instance_double('Logger', info: nil) }

      before do
        allow(described_class).to receive(:new).and_return(fake_deployments_state)
      end

      context 'when bosh-deployments.yml exists in directory' do
        let(:deployments) do
          {
            'instances' => [
              { 'name' => 'micro-bar' },
            ],
            'disks' => [],
          }
        end

        before do
          allow(File).to receive(:exists?).and_return(true)
          allow(Psych).to receive(:load_file).and_return(deployments)
        end

        it 'initializes with deployments parsed from bosh-deployments.yml' do
          expect(described_class.load_from_dir('fake-dir', logger)).to eq(fake_deployments_state)
          expect(described_class).to have_received(:new).with(deployments, deployments_file)
        end
      end

      context 'when bosh-deployments.yml does not exist in directory' do
        let(:deployments) { { 'instances' => [], 'disks' => [] } }
        before do
          allow(File).to receive(:exists?).and_return(false)
        end

        it 'initializes with an empty deployment' do
          expect(described_class.load_from_dir('fake-dir', logger)).to eq(fake_deployments_state)
          expect(described_class).to have_received(:new).with(deployments, deployments_file)
        end
      end
    end

    describe '#load_deployment' do
      subject { described_class.new(deployments, deployments_file) }
      let(:deployments) do
        {
          'instances' => [
            { name: 'micro-bar' },
          ],
          'disks' => [
            { uuid: 'fake-disk-uuid' },
          ],
        }
      end
      let(:infrastructure) do
        instance_double(
          'Bosh::Deployer::InstanceManager::Vsphere',
        )
      end

      let(:models_instance) do
        double(
          'Bosh::Deployer::Models::Instance',
          insert_multiple: nil,
          find: nil,
          new: instance_state,
        )
      end
      before do
        # Because it's hard to unit test interactions with Sequel Models
        allow(subject).to receive(:models_instance).and_return(models_instance)
      end
      let(:instance_state) do
        double(
          'Bosh::Deployer::Models::Instance',
          :uuid= => nil,
          :name= => nil,
          :stemcell_sha1= => nil,
          :save => nil,
        )
      end

      it 'inserts deployments instances into instance table' do
        subject.load_deployment('micro-bar')
        expect(models_instance).to have_received(:insert_multiple).with(deployments['instances'])
      end

      it 'looks up the instance with the given name' do
        subject.load_deployment('micro-bar')
        expect(models_instance).to have_received(:find).with(name: 'micro-bar')
      end

      context 'when instance model is found' do
        before do
          allow(models_instance).to receive(:find).and_return(instance_state)
        end
        let(:instance_state) { double('Bosh::Deployer::Models::Instance') }

        it 'sets state to instance model' do
          subject.load_deployment('micro-bar')
          expect(subject.state).to eq(instance_state)
        end
      end

      context 'when instance model is not found' do
        before do
          allow(SecureRandom).to receive(:uuid).and_return('fake-instance-uuid')
        end

        it 'sets state to a new persisted instance model' do
          expect(instance_state).to receive(:uuid=).with('bm-fake-instance-uuid').ordered
          expect(instance_state).to receive(:name=).with('micro-bar').ordered
          expect(instance_state).to receive(:stemcell_sha1=).with(nil).ordered
          expect(instance_state).to receive(:save).ordered

          subject.load_deployment('micro-bar')
          expect(subject.state).to eq(instance_state)
        end
      end
    end

    describe '#save' do

    end

    describe '#exits?' do

    end
  end
end
