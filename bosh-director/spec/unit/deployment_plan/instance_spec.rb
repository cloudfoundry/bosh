require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe Instance do

    let(:domain_name) { 'test_domain' }

    before do
      Bosh::Director::Config.stub(dns_domain_name: domain_name)
    end

    let(:index) { 0 }
    let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'mycloud') }
    subject(:instance) { Instance.new(job, index) }
    let(:plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', canonical_name: 'mycloud', model: deployment) }

    describe :network_settings do
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', deployment: plan, canonical_name: 'job') }
      let(:network_name) { 'net_a' }
      let(:cloud_properties) { { 'foo' => 'bar' } }
      let(:dns) { ['1.2.3.4'] }
      let(:dns_record_name) { "0.job.net-a.mycloud.#{domain_name}" }
      let(:ipaddress) { '10.0.0.6' }
      let(:subnet_range) { '10.0.0.1/24' }
      let(:netmask) { '255.255.255.0' }
      let(:gateway) { '10.0.0.1' }
      let(:network_settings) {
        {
          'cloud_properties' => cloud_properties,
          'dns' => dns,
          'dns_record_name' => dns_record_name
        }
      }
      let(:network_info) {
        {
          'ip' => ipaddress,
          'netmask' => netmask,
          'gateway' => gateway,
        }
      }
      let(:current_state) { { 'networks' => { network_name => network_info } } }

      before do
        job.stub(:instance_state).with(0).and_return('started')
        job.stub(:default_network).and_return({})
      end

      context 'dynamic network' do
        let(:network_type) { 'dynamic' }
        let(:dynamic_network) {
          DynamicNetwork.new(plan, {
            'name' => network_name,
            'cloud_properties' => cloud_properties,
            'dns' => dns
          })
        }
        let(:reservation) { Bosh::Director::NetworkReservation.new_dynamic }
        let(:dynamic_network_settings) {
          { network_name => network_settings.merge('type' => network_type) }
        }
        let(:dynamic_network_settings_info) {
          { network_name => network_settings.merge(network_info).merge('type' => network_type) }
        }

        it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
          plan.stub(:network).with(network_name).and_return(dynamic_network)
          dynamic_network.reserve(reservation)

          instance.add_network_reservation(network_name, reservation)
          expect(instance.network_settings).to eql(dynamic_network_settings)

          instance.current_state = current_state
          expect(instance.network_settings).to eql(dynamic_network_settings_info)
        end
      end

      context 'manual network' do
        let(:network_type) { 'manual' }
        let(:manual_network) {
          ManualNetwork.new(plan, {
            'name' => network_name,
            'dns' => dns,
            'subnets' => [{
                            'range' => subnet_range,
                            'gateway' => gateway,
                            'dns' => dns,
                            'cloud_properties' => cloud_properties
                          }]
          })
        }
        let(:reservation) { Bosh::Director::NetworkReservation.new_static(ipaddress) }
        let(:manual_network_settings) {
          { network_name => network_settings.merge(network_info) }
        }

        it 'returns the network settings as set at the network spec' do
          plan.stub(:network).with(network_name).and_return(manual_network)
          manual_network.reserve(reservation)

          instance.add_network_reservation(network_name, reservation)
          expect(instance.network_settings).to eql(manual_network_settings)

          instance.current_state = current_state
          expect(instance.network_settings).to eql(manual_network_settings)
        end
      end
    end

    describe 'binding unallocated VM' do
      let(:index) { 2 }
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', deployment: plan, name: 'dea') }
      let(:net) { instance_double('Bosh::Director::DeploymentPlan::Network', name: 'net_a') }
      let(:rp) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', network: net) }
      let(:old_ip) { NetAddr::CIDR.create('10.0.0.5').to_i }
      let(:idle_vm_ip) { NetAddr::CIDR.create('10.0.0.3').to_i }
      let(:old_reservation) { Bosh::Director::NetworkReservation.new_dynamic(old_ip) }
      let(:idle_vm_reservation) { Bosh::Director::NetworkReservation.new_dynamic(idle_vm_ip) }
      let(:idle_vm) { IdleVm.new(rp) }

      before do
        job.stub(:instance_state).with(2).and_return('started')
        job.stub(resource_pool: rp)
        idle_vm.use_reservation(idle_vm_reservation)
      end

      it 'binds a VM from job resource pool (real VM exists)' do
        idle_vm.vm = Bosh::Director::Models::Vm.make

        rp.should_receive(:allocate_vm).and_return(idle_vm)

        instance.add_network_reservation('net_a', old_reservation)
        instance.bind_unallocated_vm

        instance.model.should_not be_nil
        instance.idle_vm.should == idle_vm
        idle_vm.bound_instance.should be_nil
        idle_vm.network_reservation.ip.should == idle_vm_ip
      end

      it "binds a VM from job resource pool (real VM doesn't exist)" do
        idle_vm.vm.should be_nil

        rp.should_receive(:allocate_vm).and_return(idle_vm)
        net.should_receive(:release).with(idle_vm_reservation)

        instance.add_network_reservation('net_a', old_reservation)
        instance.bind_unallocated_vm

        instance.model.should_not be_nil
        instance.idle_vm.should == idle_vm
        idle_vm.bound_instance.should == instance
        idle_vm.network_reservation.should be_nil
      end
    end

    describe 'syncing state' do
      let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job', deployment: plan, name: 'dea') }
      let(:index) { 3 }

      it 'deployment plan -> DB' do
        job.stub(:instance_state).with(3).and_return('stopped')

        expect {
          instance.sync_state_with_db
        }.to raise_error(Bosh::Director::DirectorError, /model is not bound/)

        instance.bind_model
        instance.model.state.should == 'started'
        instance.sync_state_with_db
        instance.state.should == 'stopped'
        instance.model.state.should == 'stopped'
      end

      it 'DB -> deployment plan' do
        job.stub(:instance_state).with(3).and_return(nil)

        instance.bind_model
        instance.model.update(:state => 'stopped')

        instance.sync_state_with_db
        instance.model.state.should == 'stopped'
        instance.state.should == 'stopped'
      end

      it 'needs to find state in order to sync it' do
        job.stub(:instance_state).with(3).and_return(nil)

        instance.bind_model
        instance.model.should_receive(:state).and_return(nil)

        expect {
          instance.sync_state_with_db
        }.to raise_error(Bosh::Director::InstanceTargetStateUndefined)
      end
    end

    describe 'updating deployment' do
      let(:job) { Job.new(plan) }
      let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion') }
      let(:template) { instance_double('Bosh::Director::DeploymentPlan::Template') }

      it 'needs to smartly compare specs before deciding to update a job' do
        job.release = release
        job.templates = [template]
        job.stub(name: 'dea')
        job.release.should_receive(:name).twice.and_return('hbase-release')

        template.should_receive(:name).exactly(4).times.and_return('hbase_slave')
        template.should_receive(:version).exactly(4).times.and_return('2')
        template.should_receive(:sha1).exactly(4).times.and_return('24aeaf29768a100d500615dc02ae6126e019f99f')
        template.should_receive(:blobstore_id).exactly(4).times.and_return('4ec237cb-5f07-4658-aabe-787c82f39c76')
        template.should_receive(:logs).exactly(4).times

        job.should_receive(:instance_state).and_return('some_state')
        instance.current_state = {
          'job' => {
            'name' => 'hbase_slave',
            'release' => 'hbase-release',
            'template' => 'hbase_slave',
            'version' => '0.9-dev',
            'sha1' => 'a8ab636b7c340f98891178096a44c09487194f03',
            'blobstore_id' => 'e2e4e58e-a40e-43ec-bac5-fc50457d5563'
          }
        }
        instance.job_changed?.should == true
        # Check that the old way of comparing would say that the job has changed.
        expect(job.spec).to_not eq instance.current_state
      end

      describe 'changes' do
        let(:resource_pool) {
          instance_double('Bosh::Director::DeploymentPlan::ResourcePool',
                          spec: { 'foo' => 'bar' },
                          env: { 'key' => 'value' })
        }
        let(:job) { Job.new(plan) }

        before do
          job.stub(:instance_state).with(0).and_return('started')
          job.stub(:resource_pool).and_return(resource_pool)

          plan.stub(recreate: false)
        end

        it 'detects resource pool change when instance VM env changes' do
          instance_model = Bosh::Director::Models::Instance.make
          instance_model.vm.update(:env => { 'key' => 'value' })

          instance.current_state = { 'resource_pool' => { 'foo' => 'bar' } }
          instance.use_model(instance_model)

          instance.resource_pool_changed?.should be(false)
          instance_model.vm.update(env: { 'key' => 'value2' })

          instance.resource_pool_changed?.should be(true)
        end
      end

      describe 'spec' do
        let(:job_spec) { { name: 'job', release: 'release', templates: [] } }
        let(:release_spec) { { name: 'release', version: '1.1-dev' } }
        let(:resource_pool_spec) { { 'name' => 'default', 'stemcell' => { 'name' => 'stemcell-name', 'version' => '1.0' } } }
        let(:packages) { { 'pkg' => { 'name' => 'package', 'version' => '1.0' } } }
        let(:properties) { { 'key' => 'value' } }
        let(:reservation) { Bosh::Director::NetworkReservation.new_dynamic }
        let(:network_spec) { { 'name' => 'default', 'cloud_properties' => { 'foo' => 'bar' } } }
        let(:resource_pool) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', spec: resource_pool_spec) }
        let(:release) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', spec: release_spec) }
        let(:network) {
          network = DynamicNetwork.new(plan, network_spec)
          network.reserve(reservation)
          network
        }
        let(:job) {
          job = instance_double('Bosh::Director::DeploymentPlan::Job',
                       deployment: plan,
                       spec: job_spec,
                       canonical_name: 'job',
                       instances: ['instance0'],
                       release: release,
                       default_network: {},
                       resource_pool: resource_pool,
                       package_spec: packages,
                       persistent_disk: 0,
                       properties: properties)
        }

        before do
          plan.stub(network: network)
          plan.stub(name: 'mycloud')
          job.stub(:instance_state).with(index).and_return('started')
        end

        it 'returns instance spec' do
          network_name = network_spec['name']
          instance.add_network_reservation(network_name, reservation)

          spec = instance.spec
          expect(spec['deployment']).to eq('mycloud')
          expect(spec['release']).to eq(release_spec)
          expect(spec['job']).to eq(job_spec)
          expect(spec['index']).to eq(index)
          expect(spec['networks']).to include(network_name)

          expect_dns_name = "#{index}.#{job.canonical_name}.#{network_name}.#{plan.canonical_name}.#{domain_name}"
          expect(spec['networks'][network_name]).to include(
            'type' => 'dynamic',
            'cloud_properties' => network_spec['cloud_properties'],
            'dns_record_name' => expect_dns_name
          )

          expect(spec['resource_pool']).to eq(resource_pool_spec)
          expect(spec['packages']).to eq(packages)
          expect(spec['persistent_disk']).to eq(0)
          expect(spec['configuration_hash']).to be_nil
          expect(spec['properties']).to eq(properties)
          expect(spec['dns_domain_name']).to eq(domain_name)
        end

        it 'includes rendered_templates_archive key after rendered templates were archived' do
          instance.rendered_templates_archive =
            RenderedTemplatesArchive.new('fake-blobstore-id', 'fake-sha1')

          expect(instance.spec['rendered_templates_archive']).to eq(
            'blobstore_id' => 'fake-blobstore-id',
            'sha1' => 'fake-sha1',
          )
        end

        it 'does not include rendered_templates_archive key before rendered templates were archived' do
          expect(instance.spec).to_not have_key('rendered_templates_archive')
        end
      end
    end
  end
end
