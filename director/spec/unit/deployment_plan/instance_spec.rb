# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::Instance do

  let(:domain_name) { 'test_domain' }

  before(:each) do
    BD::Config.stub(:dns_domain_name).and_return(domain_name)
  end

  def make(job, index)
    BD::DeploymentPlan::Instance.new(job, index)
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  describe :network_settings do
    let(:plan) { double(BD::DeploymentPlan, :canonical_name => 'mycloud') }
    let(:job)  { double(BD::DeploymentPlan::Job, :deployment => plan, :canonical_name => 'job') }
    let(:network_name) {'net_a'}
    let(:cloud_properties) { { 'foo' => 'bar' } }
    let(:dns) { [ '1.2.3.4' ] }
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
      let(:dynamic_network)  {
        BD::DeploymentPlan::DynamicNetwork.new(plan, {
          'name' => network_name,
          'cloud_properties' => cloud_properties,
          'dns' => dns
        })
      }
      let(:reservation) { BD::NetworkReservation.new_dynamic }
      let(:dynamic_network_settings) {
        { network_name => network_settings.merge('type' => network_type) }
      }
      let(:dynamic_network_settings_info) {
        { network_name => network_settings.merge(network_info).merge('type' => network_type) }
      }

      it 'returns the network settings plus current IP, Netmask & Gateway from agent state' do
        plan.stub(:network).with(network_name).and_return(dynamic_network)
        dynamic_network.reserve(reservation)

        instance = make(job, 0)
        instance.add_network_reservation(network_name, reservation)
        expect(instance.network_settings).to eql(dynamic_network_settings)

        instance.current_state = current_state
        expect(instance.network_settings).to eql(dynamic_network_settings_info)
      end
    end

    context 'manual network' do
      let(:network_type) { 'manual' }
      let(:manual_network)  {
        BD::DeploymentPlan::ManualNetwork.new(plan, {
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
      let(:reservation) { BD::NetworkReservation.new_static(ipaddress) }
      let(:manual_network_settings) {
        { network_name => network_settings.merge(network_info) }
      }

      it 'returns the network settings as set at the network spec' do
        plan.stub(:network).with(network_name).and_return(manual_network)
        manual_network.reserve(reservation)

        instance = make(job, 0)
        instance.add_network_reservation(network_name, reservation)
        expect(instance.network_settings).to eql(manual_network_settings)

        instance.current_state = current_state
        expect(instance.network_settings).to eql(manual_network_settings)
      end
    end
  end

  describe "binding unallocated VM" do
    before(:each) do
      @deployment = make_deployment("mycloud")
      @plan = double(BD::DeploymentPlan, :model => @deployment)
      @job = double(BD::DeploymentPlan::Job, :deployment => @plan)
      @job.stub(:name).and_return("dea")
      @job.stub(:instance_state).with(2).and_return("started")
      @instance = make(@job, 2)
    end

    it "binds a VM from job resource pool (real VM exists)" do
      net = double(BD::DeploymentPlan::Network, :name => "net_a")
      rp = double(BD::DeploymentPlan::ResourcePool, :network => net)
      @job.stub(:resource_pool).and_return(rp)

      old_ip = NetAddr::CIDR.create("10.0.0.5").to_i
      idle_vm_ip = NetAddr::CIDR.create("10.0.0.3").to_i

      old_reservation = BD::NetworkReservation.new_dynamic(old_ip)
      idle_vm_reservation = BD::NetworkReservation.new_dynamic(idle_vm_ip)

      idle_vm = BD::DeploymentPlan::IdleVm.new(rp)
      idle_vm.use_reservation(idle_vm_reservation)
      idle_vm.vm = BD::Models::Vm.make

      rp.should_receive(:allocate_vm).and_return(idle_vm)

      @instance.add_network_reservation("net_a", old_reservation)
      @instance.bind_unallocated_vm

      @instance.model.should_not be_nil
      @instance.idle_vm.should == idle_vm
      idle_vm.bound_instance.should be_nil
      idle_vm.network_reservation.ip.should == idle_vm_ip
    end

    it "binds a VM from job resource pool (real VM doesn't exist)" do
      net = double(BD::DeploymentPlan::Network, :name => "net_a")
      rp = double(BD::DeploymentPlan::ResourcePool, :network => net)
      @job.stub(:resource_pool).and_return(rp)

      old_ip = NetAddr::CIDR.create("10.0.0.5").to_i
      idle_vm_ip = NetAddr::CIDR.create("10.0.0.3").to_i

      old_reservation = BD::NetworkReservation.new_dynamic(old_ip)
      idle_vm_reservation = BD::NetworkReservation.new_dynamic(idle_vm_ip)

      idle_vm = BD::DeploymentPlan::IdleVm.new(rp)
      idle_vm.use_reservation(idle_vm_reservation)
      idle_vm.vm.should be_nil

      rp.should_receive(:allocate_vm).and_return(idle_vm)
      net.should_receive(:release).with(idle_vm_reservation)

      @instance.add_network_reservation("net_a", old_reservation)
      @instance.bind_unallocated_vm

      @instance.model.should_not be_nil
      @instance.idle_vm.should == idle_vm
      idle_vm.bound_instance.should == @instance
      idle_vm.network_reservation.should be_nil
    end
  end

  describe "syncing state" do
    before(:each) do
      @deployment = make_deployment("mycloud")
      @plan = double(BD::DeploymentPlan, :model => @deployment)
      @job = double(BD::DeploymentPlan::Job, :deployment => @plan)
      @job.stub(:name).and_return("dea")
    end

    it "deployment plan -> DB" do
      @job.stub(:instance_state).with(3).and_return("stopped")
      instance = make(@job, 3)

      expect {
        instance.sync_state_with_db
      }.to raise_error(BD::DirectorError, /model is not bound/)

      instance.bind_model
      instance.model.state.should == "started"
      instance.sync_state_with_db
      instance.state.should == "stopped"
      instance.model.state.should == "stopped"
    end

    it "DB -> deployment plan" do
      @job.stub(:instance_state).with(3).and_return(nil)
      instance = make(@job, 3)

      instance.bind_model
      instance.model.update(:state => "stopped")

      instance.sync_state_with_db
      instance.model.state.should == "stopped"
      instance.state.should == "stopped"
    end

    it "needs to find state in order to sync it" do
      @job.stub(:instance_state).with(3).and_return(nil)
      instance = make(@job, 3)

      instance.bind_model
      instance.model.should_receive(:state).and_return(nil)

      expect {
        instance.sync_state_with_db
      }.to raise_error(BD::InstanceTargetStateUndefined)
    end
  end

  describe "updating deployment" do
    it "needs to smartly compare specs before deciding to update a job" do
      @deployment = make_deployment("mycloud")
      @plan = double(BD::DeploymentPlan, :model => @deployment)
      @job = BD::DeploymentPlan::Job.new(@plan, {})

      @job.release = double(BD::DeploymentPlan::Release)
      @job.release.should_receive(:name).twice.and_return("hbase-release")

      mock_template = double(BD::DeploymentPlan::Template)
      mock_template.should_receive(:name).exactly(4).times.and_return(
        "hbase_slave")
      mock_template.should_receive(:version).exactly(4).times.and_return("2")
      mock_template.should_receive(:sha1).exactly(4).times.and_return(
        "24aeaf29768a100d500615dc02ae6126e019f99f")
      mock_template.should_receive(:blobstore_id).exactly(4).times.and_return(
        "4ec237cb-5f07-4658-aabe-787c82f39c76")
      mock_template.should_receive(:logs).exactly(4).times

      @job.templates = [mock_template]
      @job.should_receive(:instance_state).and_return("some_state")
      instance = make(@job, 0)
      @job.stub(:name).and_return("dea")
      instance.current_state = {
        "job" => {
          "name" => "hbase_slave",
          "release" => "hbase-release",
          "template" => "hbase_slave",
          "version" => "0.9-dev",
          "sha1" => "a8ab636b7c340f98891178096a44c09487194f03",
          "blobstore_id" => "e2e4e58e-a40e-43ec-bac5-fc50457d5563"
        }
      }
      instance.job_changed?.should == true
      # Check that the old way of comparing would say that the job has changed.
      (@job.spec == instance.current_state).should == false
    end

    describe "changes" do
      it "detects resource pool change when instance VM env changes" do
        deployment = make_deployment("mycloud")

        resource_pool = double(BD::DeploymentPlan::ResourcePool)
        resource_pool.stub(:spec).and_return("foo" => "bar")
        resource_pool.stub(:env).and_return("key" => "value")

        plan = double(BD::DeploymentPlan, :model => deployment)
        plan.stub(:recreate).and_return(false)

        job = BD::DeploymentPlan::Job.new(plan, {})
        job.stub(:instance_state).with(0).and_return("started")
        job.stub(:resource_pool).and_return(resource_pool)

        instance_model = BD::Models::Instance.make
        instance_model.vm.update(:env => {"key" => "value"})

        instance = make(job, 0)
        instance.current_state = {"resource_pool" => {"foo" => "bar"}}
        instance.use_model(instance_model)

        instance.resource_pool_changed?.should be_false
        instance_model.vm.update(:env => {"key" => "value2"})

        instance.resource_pool_changed?.should be_true
      end
    end

    describe 'spec' do
      let(:deployment_name) { 'mycloud' }
      let(:job_spec) { {:name => 'job', :release => 'release', :templates => []} }
      let(:job_index) { 0 }
      let(:release_spec) { {:name => 'release', :version => '1.1-dev'} }
      let(:resource_pool_spec) { {'name' => 'default', 'stemcell' => {'name' => 'stemcell-name', 'version' => '1.0'}} }
      let(:packages) { {'pkg' => {'name' => 'package', 'version' => '1.0'}} }
      let(:properties) { {'key' => 'value'} }
      let(:reservation)  { BD::NetworkReservation.new_dynamic }
      let(:network_spec) { {'name' => 'default', 'cloud_properties' => {'foo' => 'bar'}} }

      it 'returns instance spec' do
        deployment = make_deployment('mycloud')
        plan = double(BD::DeploymentPlan, :model => deployment, :name => deployment_name, :canonical_name => deployment_name)
        job = double(BD::DeploymentPlan::Job, :deployment => plan, :spec => job_spec,
                   :canonical_name => 'job', :instances => ['instance0'])
        release = double(BD::DeploymentPlan::Release, :spec => release_spec)
        resource_pool = double(BD::DeploymentPlan::ResourcePool, :spec => resource_pool_spec)

        network = BD::DeploymentPlan::DynamicNetwork.new(plan, network_spec)
        network.reserve(reservation)
        plan.stub(:network).and_return(network)

        job.stub(:release).and_return(release)
        job.stub(:instance_state).with(job_index).and_return('started')
        job.stub(:default_network).and_return({})
        job.stub(:resource_pool).and_return(resource_pool)
        job.stub(:package_spec).and_return(packages)
        job.stub(:persistent_disk).and_return(0)
        job.stub(:properties).and_return(properties)

        instance = make(job, job_index)
        instance.add_network_reservation(network_spec['name'], reservation)

        spec = instance.spec
        expect(spec['deployment']).to eql(deployment_name)
        expect(spec['release']).to eql(release_spec)
        expect(spec['job']).to eql(job_spec)
        expect(spec['index']).to eql(job_index)
        expect(spec['networks']).to include(network_spec['name'])
        expect(spec['networks'][network_spec['name']]).to include(
          'type' => 'dynamic',
          'cloud_properties' => network_spec['cloud_properties'],
          'dns_record_name' => "#{job_index}.#{job.canonical_name}.#{network_spec['name']}.#{plan.canonical_name}.#{domain_name}"
        )
        expect(spec['resource_pool']).to eql(resource_pool_spec)
        expect(spec['packages']).to eql(packages)
        expect(spec['persistent_disk']).to eql(0)
        expect(spec['configuration_hash']).to eql(nil)
        expect(spec['properties']).to eql(properties)
        expect(spec['dns_domain_name']).to eql(domain_name)
      end
    end

  end
end
