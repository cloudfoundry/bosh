require 'spec_helper'

module Bosh::Director
  describe Jobs::DynamicDisks::ProvideDynamicDisk do
    let(:agent_id) { 'fake-agent-id' }
    let(:reply) { 'inbox.fake' }
    let(:disk_name) { 'fake-disk-name' }
    let(:disk_cid) { 'fake-disk-cid' }
    let(:disk_pool_name) { 'fake-disk-pool-name' }
    let(:disk_cloud_properties) { { 'fake-disk-cloud-property-key' => 'fake-disk-cloud-property-value' } }
    let(:disk_size) { 1000 }
    let(:metadata) { { 'fake-key' => 'fake-value' } }
    let(:disk_hint) { 'fake-disk-hint' }

    let(:nats_rpc) { instance_double(Bosh::Director::NatsRpc) }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:provide_dynamic_disk_job) { Jobs::DynamicDisks::ProvideDynamicDisk.new(agent_id, reply, disk_name, disk_pool_name, disk_size, metadata) }
    let!(:vm) { FactoryBot.create(:models_vm, agent_id: agent_id, cid: 'fake-vm-cid') }
    let!(:cloud_config) do
      FactoryBot.create(:models_config_cloud, content: YAML.dump(
        SharedSupport::DeploymentManifestHelper.simple_cloud_config.merge(
          'disk_types' => [
            { 'name' => disk_pool_name,
              'disk_size' => 1024,
              'cloud_properties' => disk_cloud_properties
            }
          ]
        )
      ))
    end
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory, get: cloud) }

    before do
      allow(Config).to receive(:nats_rpc).and_return(nats_rpc)
      allow(Bosh::Director::Config).to receive(:name).and_return('fake-director-name')
      allow(Bosh::Director::Config).to receive(:cloud_options).and_return('provider' => { 'path' => '/path/to/default/cpi' })
      allow(Bosh::Director::Config).to receive(:preferred_cpi_api_version).and_return(2)
      allow(CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud).to receive(:respond_to?).with(:set_disk_metadata).and_return(false)
    end

    describe '#perform' do
      context 'when disk exists' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: vm.instance.deployment,
            disk_pool_name: disk_pool_name,
          )
        end

        it 'attaches the disk to VM and updates disk vm and availability zone' do
          expect(cloud).not_to receive(:create_disk)
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_return(disk_hint)
          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => nil,
            'disk_name' => disk_name,
            'disk_hint' => disk_hint,
          })
          expect(provide_dynamic_disk_job.perform).to eq("attached disk `#{disk_name}` to `#{vm.cid}` in deployment `#{vm.instance.deployment.name}`")

          model = Models::DynamicDisk.where(disk_cid: disk_cid).first
          expect(model.vm).to eq(vm)
          expect(model.availability_zone).to eq(vm.instance.availability_zone)
        end
      end

      context 'when disk does not exist' do
        it 'creates the disk and attaches it to VM' do
          expect(cloud).to receive(:create_disk).with(disk_size, disk_cloud_properties, vm.cid).and_return(disk_cid)
          expect(cloud).to receive(:respond_to?).with(:set_disk_metadata).and_return(false)
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_return(disk_hint)

          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => nil,
            'disk_name' => disk_name,
            'disk_hint' => disk_hint,
          })
          expect(provide_dynamic_disk_job.perform).to eq("attached disk `#{disk_name}` to `#{vm.cid}` in deployment `#{vm.instance.deployment.name}`")

          model = Models::DynamicDisk.where(disk_cid: disk_cid).first
          expect(model.name).to eq(disk_name)
          expect(model.size).to eq(disk_size)
          expect(model.deployment_id).to eq(vm.instance.deployment.id)
          expect(model.disk_pool_name).to eq(disk_pool_name)
          expect(model.cpi).to eq(vm.cpi)
          expect(model.vm).to eq(vm)
          expect(model.availability_zone).to eq(vm.instance.availability_zone)
          expect(model.metadata).to eq(metadata)
        end
      end

      context 'when disk exists in database but not in the cloud' do
        let!(:disk) do
          FactoryBot.create(
            :models_dynamic_disk,
            name: disk_name,
            disk_cid: disk_cid,
            deployment: vm.instance.deployment,
            disk_pool_name: disk_pool_name,
          )
        end

        it 'returns an error from attach_disk call' do
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_raise('some-error')

          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => 'some-error'
          })
          expect { provide_dynamic_disk_job.perform }.to raise_error('some-error')
        end
      end

      context 'when disk type can not be found in cloud config' do
        let!(:cloud_config) do
          FactoryBot.create(:models_config_cloud, content: YAML.dump(
            SharedSupport::DeploymentManifestHelper.simple_cloud_config.merge(
              'disk_types' => [
                { 'name' => 'different-disk-type',
                  'disk_size' => 1024,
                  'cloud_properties' => {}
                }
              ]
            )
          ))
        end

        it 'responds with error' do
          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => "Could not find disk pool by name `fake-disk-pool-name`"
          })
          expect { provide_dynamic_disk_job.perform }.to raise_error("Could not find disk pool by name `fake-disk-pool-name`")
        end
      end

      context 'when cpi supports set_disk_metadata' do
        it 'sets disk metadata' do
          expect(cloud).to receive(:create_disk).with(disk_size, disk_cloud_properties, vm.cid).and_return('fake-disk-cid')
          expect(cloud).to receive(:respond_to?).with(:set_disk_metadata).and_return(true)
          expect(cloud).to receive(:set_disk_metadata).with(
            'fake-disk-cid',
            {
              "deployment" => vm.instance.deployment.name,
              "director" => 'fake-director-name',
              "fake-key" => "fake-value"
            }
          )
          expect(cloud).to receive(:attach_disk).with('fake-vm-cid', 'fake-disk-cid').and_return(disk_hint)

          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => nil,
            'disk_name' => disk_name,
            'disk_hint' => disk_hint,
          })
          expect(provide_dynamic_disk_job.perform).to eq("attached disk `#{disk_name}` to `#{vm.cid}` in deployment `#{vm.instance.deployment.name}`")
        end
      end

      context 'when teams are set on the deployment' do
        let(:team_1) { FactoryBot.create(:models_team, name: 'team-1') }
        let(:team_2) { FactoryBot.create(:models_team, name: 'team-2') }
        let(:other_team) { FactoryBot.create(:models_team, name: 'other_team') }
        let(:other_disk_cloud_properties) { { 'other-disk-cloud-properties' => {} } }
        let!(:latest_other_cloud_config) do
          FactoryBot.create(:models_config_cloud, team_id: other_team.id, content: YAML.dump(
            SharedSupport::DeploymentManifestHelper.simple_cloud_config.merge(
              'disk_types' => [
                { 'name' => disk_pool_name,
                  'disk_size' => 1024,
                  'cloud_properties' => other_disk_cloud_properties,
                }
              ]
            )
          ))
        end

        before do
          vm.instance.deployment.update(teams: [team_1, team_2])
          cloud_config.update(team_id: team_1.id)
        end

        it 'gets the disk cloud properties from the latest cloud config for those teams' do
          expect(cloud).to receive(:create_disk).with(disk_size, disk_cloud_properties, vm.cid).and_return(disk_cid)
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk_cid).and_return(disk_hint)
          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => nil,
            'disk_name' => disk_name,
            'disk_hint' => disk_hint,
          })
          expect(provide_dynamic_disk_job.perform).to eq("attached disk `#{disk_name}` to `#{vm.cid}` in deployment `#{vm.instance.deployment.name}`")
        end
      end

      context 'when VM cannot be found' do
        let!(:vm) { FactoryBot.create(:models_vm, agent_id: 'different-agent-id', cid: 'fake-vm-cid') }

        it 'responds with error' do
          expect(nats_rpc).to receive(:send_message).with(reply, {
            'error' => "vm for agent `fake-agent-id` not found"
          })
          expect { provide_dynamic_disk_job.perform }.to raise_error("vm for agent `fake-agent-id` not found")
        end
      end
    end
  end
end
