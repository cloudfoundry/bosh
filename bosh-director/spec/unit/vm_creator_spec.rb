require 'spec_helper'
require 'timecop'

describe Bosh::Director::VmCreator do

  subject { Bosh::Director::VmCreator.new(
    cloud, logger, vm_deleter, disk_manager, job_renderer, arp_flusher
  ) }

  let(:disk_manager) { Bosh::Director::DiskManager.new(cloud, logger) }
  let(:cloud) { instance_double('Bosh::Cloud') }
  let(:vm_deleter) {Bosh::Director::VmDeleter.new(cloud, logger)}
  let(:job_renderer) { instance_double(Bosh::Director::JobRenderer) }
  let(:arp_flusher) { instance_double(Bosh::Director::ArpFlusher) }
  let(:agent_client) do
    instance_double(
      Bosh::Director::AgentClient,
      wait_until_ready: nil,
      update_settings: nil,
      apply: nil,
      get_state: nil
    )
  end
  let(:network_settings) { BD::DeploymentPlan::NetworkSettings.new(job.name, 'deployment_name', {'gateway' => 'name'}, [reservation], {}, availability_zone, 5, 'uuid-1',  BD::DnsManagerProvider.create).to_hash }
  let(:deployment) { Bosh::Director::Models::Deployment.make(name: 'deployment_name') }
  let(:deployment_plan) do
    instance_double(Bosh::Director::DeploymentPlan::Planner, model: deployment, name: 'deployment_name', recreate: false)
  end
  let(:availability_zone) do
    BD::DeploymentPlan::AvailabilityZone.new('az-1', {})
  end
  let(:vm_type) { Bosh::Director::DeploymentPlan::VmType.new({'name' => 'fake-vm-type', 'cloud_properties' => {'ram' => '2gb'}}) }
  let(:stemcell_model) { Bosh::Director::Models::Stemcell.make(:cid => 'stemcell-id', name: 'fake-stemcell', version: '123') }
  let(:stemcell) do
    stemcell_model
    stemcell = Bosh::Director::DeploymentPlan::Stemcell.parse({'name' => 'fake-stemcell', 'version' => '123'})
    stemcell.add_stemcell_model
    stemcell
  end
  let(:env) { Bosh::Director::DeploymentPlan::Env.new({}) }

  let(:instance) do
    instance = Bosh::Director::DeploymentPlan::Instance.create_from_job(
      job,
      5,
      'started',
      deployment,
      {},
      nil,
      logger
    )
    instance.bind_existing_instance_model(instance_model)
    allow(instance).to receive(:apply_spec).and_return({})
    instance
  end
  let(:reservation) do
    subnet = BD::DeploymentPlan::DynamicNetworkSubnet.new('dns', {'ram' => '2gb'}, ['az-1'])
    network = BD::DeploymentPlan::DynamicNetwork.new('name', [subnet], logger)
    reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, network)
  end
  let(:instance_plan) do
    desired_instance = BD::DeploymentPlan::DesiredInstance.new(job, {}, nil)
    network_plan = BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)
    BD::DeploymentPlan::InstancePlan.new(existing_instance: instance_model, desired_instance: desired_instance, instance: instance, network_plans: [network_plan])
  end

  let(:job) do
    template_model = BD::Models::Template.make
    template = BD::DeploymentPlan::Template.new(nil, 'fake-template')
    template.bind_existing_model(template_model)

    job = BD::DeploymentPlan::Job.new(logger)
    job.name = 'fake-job'
    job.vm_type = vm_type
    job.stemcell = stemcell
    job.env = env
    job.templates << template
    job.default_network = {"gateway" => "name"}
    job.update = BD::DeploymentPlan::UpdateConfig.new({'canaries' => 1, 'max_in_flight' => 1, 'canary_watch_time' => '1000-2000', 'update_watch_time' => '1000-2000'})
    job
  end

  let(:extra_ip) do {
    "a"=>{
      "ip"=>"192.168.1.3",
      "netmask"=>"255.255.255.0",
      "cloud_properties"=>{},
      "default"=>["dns", "gateway"],
      "dns"=>["192.168.1.1", "192.168.1.2"],
      "gateway"=>"192.168.1.1"
    }}
  end

  let(:instance_model) { Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 5, job: 'fake-job', deployment: deployment) }

  let(:event_manager) { Bosh::Director::Api::EventManager.new(true)}
  let(:task_id) {42}
  let(:update_job) {instance_double(Bosh::Director::Jobs::UpdateDeployment, username: 'user', task_id: task_id, event_manager: event_manager)}

  before do
    allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud)
    Bosh::Director::Config.max_vm_create_tries = 2
    Bosh::Director::Config.flush_arp = true
    allow(Bosh::Director::AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent_client)
    allow(job).to receive(:instance_plans).and_return([instance_plan])
    allow(job_renderer).to receive(:render_job_instance).with(instance_plan)
    allow(arp_flusher).to receive(:delete_arp_entries)
    allow(Bosh::Director::Config).to receive(:current_job).and_return(update_job)
  end

  it 'should create a vm' do
    expect(cloud).to receive(:create_vm).with(
      kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, ['fake-disk-cid'], {}
    ).and_return('new-vm-cid')

    expect(agent_client).to receive(:wait_until_ready)
    expect(instance).to receive(:update_trusted_certs)
    expect(instance).to receive(:update_cloud_properties!)

    expect {
      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    }.to change {
        Bosh::Director::Models::Instance.where(vm_cid: 'new-vm-cid').count}.from(0).to(1)
  end

  it 'should record events' do
    expect(cloud).to receive(:create_vm).with(
        kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, ['fake-disk-cid'], {}
    ).and_return('new-vm-cid')
    expect {
      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    }.to change {
      Bosh::Director::Models::Event.count }.from(0).to(2)

    event_1 = Bosh::Director::Models::Event.first
    expect(event_1.user).to eq('user')
    expect(event_1.action).to eq('create')
    expect(event_1.object_type).to eq('vm')
    expect(event_1.object_name).to eq(nil)
    expect(event_1.task).to eq("#{task_id}")
    expect(event_1.deployment).to eq(instance_model.deployment.name)
    expect(event_1.instance).to eq(instance_model.name)

    event_2 = Bosh::Director::Models::Event.order(:id)[2]
    expect(event_2.parent_id).to eq(1)
    expect(event_2.user).to eq('user')
    expect(event_2.action).to eq('create')
    expect(event_2.object_type).to eq('vm')
    expect(event_2.object_name).to eq('new-vm-cid')
    expect(event_2.task).to eq("#{task_id}")
    expect(event_2.deployment).to eq(instance_model.deployment.name)
    expect(event_2.instance).to eq(instance_model.name)
  end

  it 'should record events about error' do
    expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))
    expect {
      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    }.to raise_error Bosh::Clouds::VMCreationFailed

    event_2 = Bosh::Director::Models::Event.order(:id)[2]
    expect(event_2.error).to eq('Bosh::Clouds::VMCreationFailed')
  end


  it 'flushes the ARP cache' do
    allow(cloud).to receive(:create_vm).with(
      kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings.merge(extra_ip), ['fake-disk-cid'], {}
    ).and_return('new-vm-cid')

    allow(instance_plan).to receive(:network_settings_hash).and_return(
      network_settings.merge(extra_ip)
    )

    subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    expect(arp_flusher).to have_received(:delete_arp_entries).with(instance_model.vm_cid, ["192.168.1.3"])
  end

  it "does not flush the arp cache when arp_flush set to false" do
    Bosh::Director::Config.flush_arp = false

    allow(cloud).to receive(:create_vm).with(
      kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings.merge(extra_ip), ['fake-disk-cid'], {}
    ).and_return('new-vm-cid')

    allow(instance_plan).to receive(:network_settings_hash).and_return(
      network_settings.merge(extra_ip)
    )

    subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    expect(arp_flusher).not_to have_received(:delete_arp_entries).with(instance_model.vm_cid, ["192.168.1.3"])

  end

  it 'sets vm metadata' do
    expect(cloud).to receive(:create_vm).with(
        kind_of(String), 'stemcell-id', kind_of(Hash), network_settings, ['fake-disk-cid'], {}
      ).and_return('new-vm-cid')

    allow(Bosh::Director::Config).to receive(:name).and_return('fake-director-name')
    Timecop.freeze do
      expect(cloud).to receive(:set_vm_metadata) do |vm_cid, metadata|
        expect(vm_cid).to eq('new-vm-cid')
        expect(metadata).to match({
          deployment: 'deployment_name',
          created_at: Time.new.getutc.strftime('%Y-%m-%dT%H:%M:%SZ'),
          job: 'fake-job',
          index: '5',
          director: 'fake-director-name',
          id: instance_model.uuid,
          name: "fake-job/#{instance_model.uuid}",
        })
      end

      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    end
  end

  it 'updates instance job templates with new IP' do
    allow(cloud).to receive(:create_vm)
    expect(job_renderer).to receive(:render_job_instance).with(instance_plan)
    expect(instance).to receive(:apply_initial_vm_state)

    subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
  end

  it 'should create credentials when encryption is enabled' do
    Bosh::Director::Config.encryption = true
    expect(cloud).to receive(:create_vm).with(kind_of(String), 'stemcell-id',
                                           kind_of(Hash), network_settings, ['fake-disk-cid'],
                                           {'bosh' =>
                                             { 'credentials' =>
                                               { 'crypt_key' => kind_of(String),
                                                 'sign_key' => kind_of(String)}}})
                                        .and_return('new-vm-cid')

    subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])

    instance_with_new_vm = Bosh::Director::Models::Instance.find(vm_cid: 'new-vm-cid')
    expect(instance_with_new_vm).not_to be_nil

    expect(Base64.strict_decode64(instance_with_new_vm.credentials['crypt_key'])).to be_kind_of(String)
    expect(Base64.strict_decode64(instance_with_new_vm.credentials['sign_key'])).to be_kind_of(String)

    expect {
      Base64.strict_decode64(instance_with_new_vm.credentials['crypt_key'] + 'foobar')
    }.to raise_error(ArgumentError, /invalid base64/)

    expect {
      Base64.strict_decode64(instance_with_new_vm.credentials['sign_key'] + 'barbaz')
    }.to raise_error(ArgumentError, /invalid base64/)
  end

  it 'should retry creating a VM if it is told it is a retryable error' do
    expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(true))
    expect(cloud).to receive(:create_vm).once.and_return('fake-vm-cid')

    expect {
      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    }.to change {
        Bosh::Director::Models::Instance.where(vm_cid: 'fake-vm-cid').count}.from(0).to(1)
  end

  it 'should not retry creating a VM if it is told it is not a retryable error' do
    expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

    expect {
      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should try exactly the configured number of times (max_vm_create_tries) when it is a retryable error' do
    Bosh::Director::Config.max_vm_create_tries = 3

    expect(cloud).to receive(:create_vm).exactly(3).times.and_raise(Bosh::Clouds::VMCreationFailed.new(true))

    expect {
      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should not destroy the VM if the Config.keep_unreachable_vms flag is true' do
    Bosh::Director::Config.keep_unreachable_vms = true
    expect(cloud).to receive(:create_vm).and_return('new-vm-cid')
    expect(cloud).to_not receive(:delete_vm)

    expect(instance).to receive(:update_trusted_certs).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

    expect {
      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  it 'should have deep copy of environment' do
    Bosh::Director::Config.encryption = true
    env_id = nil

    expect(cloud).to receive(:create_vm) do |*args|
      env_id = args[5].object_id
    end

    subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])

    expect(cloud).to receive(:create_vm) do |*args|
      expect(args[5].object_id).not_to eq(env_id)
    end

    subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
  end

  it 'should destroy the VM if the Config.keep_unreachable_vms flag is false' do
    Bosh::Director::Config.keep_unreachable_vms = false
    expect(cloud).to receive(:create_vm).and_return('new-vm-cid')
    expect(cloud).to receive(:delete_vm)

    expect(instance).to receive(:update_trusted_certs).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

    expect {
      subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
    }.to raise_error(Bosh::Clouds::VMCreationFailed)
  end

  context 'Config.generate_vm_passwords flag is true' do
    before {
      Bosh::Director::Config.generate_vm_passwords = true
    }

    context 'no password is specified' do
      it 'should generate a random VM password' do
        expect(cloud).to receive(:create_vm) do |_, _, _, _, _, env|
          expect(env['bosh']['password'].length).to_not eq(0)
        end.and_return('new-vm-cid')

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
      end
    end

    context 'password is specified' do
      let(:env) { Bosh::Director::DeploymentPlan::Env.new({'bosh' => {'password' => 'custom-password'}}) }
      it 'should generate a random VM password' do
        expect(cloud).to receive(:create_vm) do |_, _, _, _, _, env|
          expect(env['bosh']['password']).to eq('custom-password')
        end.and_return('new-vm-cid')

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
      end
    end
  end

  context 'Config.generate_vm_passwords flag is false' do
    before {
      Bosh::Director::Config.generate_vm_passwords = false
    }

    context 'no password is specified' do
      it 'should generate a random VM password' do
        expect(cloud).to receive(:create_vm) do |_, _, _, _, _, env|
          expect(env['bosh']).to be_nil
        end.and_return('new-vm-cid')

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
      end
    end

    context 'password is specified' do
      let(:env) { Bosh::Director::DeploymentPlan::Env.new({'bosh' => {'password' => 'custom-password'}}) }
      it 'should generate a random VM password' do
        expect(cloud).to receive(:create_vm) do |_, _, _, _, _, env|
          expect(env['bosh']['password']).to eq('custom-password')
        end.and_return('new-vm-cid')

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'])
      end
    end
  end
end
