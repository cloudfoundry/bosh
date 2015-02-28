require 'timeout'
require 'spec_helper'
require 'logger'

BOSH_STEMCELL_TGZ ||= 'bosh-instance-1.0.tgz'

module Bosh::Deployer
  describe InstanceManager do
    before do
      @dir = Dir.mktmpdir('bdim_spec')
      @config = Psych.load_file(spec_asset('test-bootstrap-config-vcloud.yml'))
      @config['dir'] = @dir
      @config['name'] = "spec-#{SecureRandom.uuid}"
      @config['logging'] = { 'file' => "#{@dir}/bmim.log" }
      @deployer = Bosh::Deployer::InstanceManager.create(@config)
      @cloud = double('cloud')
      allow(Bosh::Deployer::Config).to receive(:cloud).and_return(@cloud)
      @agent = double('agent')
      allow(@deployer).to receive(:agent).and_return(@agent)

      allow(MicroboshJobInstance).to receive(:new).and_return(FakeMicroboshJobInstance.new)
    end

    class FakeMicroboshJobInstance
      def render_templates(spec)
        spec
      end
    end

    after do
      @deployer.state.destroy
      FileUtils.remove_entry_secure @dir
    end

    let(:logger) { instance_double('Logger', debug: nil, info: nil) }

    def load_deployment
      deployments = Bosh::Deployer::DeploymentsState.load_from_dir(@config['dir'], logger)
      instances = deployments.deployments['instances']
      instances.detect { |d| d[:name] == @deployer.state.name }
    end

    context 'remote_tunnel_check' do
      it 'should successfully deploy when remote_tunnel method is over-ridden ' +
           'to not establish a socket connection' do
        allow(@deployer).to receive(:service_ip).and_return('10.0.0.10')
        @spec = Psych.load_file(spec_asset('apply_spec_vcloud.yml'))
        expect(Bosh::Deployer::Specification).to receive(:load_apply_spec).and_return(@spec)
        allow(Bosh::Deployer::Config).to receive(:agent_properties).and_return({})

        @registry_port = 1234

        allow(@deployer).to receive(:run_command)
        allow(@deployer).to receive(:wait_until_ready)
        allow(@deployer).to receive(:wait_until_director_ready)
        allow(@deployer).to receive(:load_apply_spec).and_return(@spec)
        allow(@deployer).to receive(:load_stemcell_manifest).and_return('cloud_properties' => {})

        expect(@deployer.state.uuid).not_to be_nil
        expect(@deployer.state.stemcell_cid).to be_nil
        expect(@deployer.state.vm_cid).to be_nil

        expect(@cloud).to receive(:create_stemcell).and_return('SC-CID-CREATE')
        expect(@cloud).to receive(:create_vm).and_return('VM-CID-CREATE')
        expect(@cloud).to receive(:create_disk).and_return('DISK-CID-CREATE')
        expect(@cloud).to receive(:attach_disk).with('VM-CID-CREATE', 'DISK-CID-CREATE')
        expect(@agent).to receive(:run_task).with(:mount_disk, 'DISK-CID-CREATE').and_return({})
        expect(@agent).to receive(:run_task).with(:stop)
        expect(@agent).to receive(:run_task).with(:apply, @spec)
        expect(@agent).to receive(:run_task).with(:start)

        expect {
          Timeout.timeout(5) do
            @deployer.create(BOSH_STEMCELL_TGZ, nil)
          end
        }.to_not raise_error

        expect(@deployer.state.stemcell_cid).to eq('SC-CID-CREATE')
        expect(@deployer.state.vm_cid).to eq('VM-CID-CREATE')
        expect(@deployer.state.disk_cid).to eq('DISK-CID-CREATE')
        expect(load_deployment).to eq(@deployer.state.values)
        expect(@deployer.renderer.total).to eq(@deployer.renderer.index)
      end
    end

    it 'should create a Bosh instance' do
      allow(@deployer).to receive(:service_ip).and_return('10.0.0.10')
      spec = Psych.load_file(spec_asset('apply_spec_vcloud.yml'))
      expect(Bosh::Deployer::Specification).to receive(:load_apply_spec).and_return(spec)
      allow(Bosh::Deployer::Config).to receive(:agent_properties).and_return({})

      allow(@deployer).to receive(:run_command)
      allow(@deployer).to receive(:wait_until_agent_ready)
      allow(@deployer).to receive(:wait_until_director_ready)
      allow(@deployer).to receive(:load_apply_spec).and_return(spec)
      allow(@deployer).to receive(:load_stemcell_manifest).and_return('cloud_properties' => {})

      expect(@deployer.state.uuid).not_to be_nil

      expect(@deployer.state.stemcell_cid).to be_nil
      expect(@deployer.state.vm_cid).to be_nil

      expect(@cloud).to receive(:create_stemcell).and_return('SC-CID-CREATE')
      expect(@cloud).to receive(:create_vm).and_return('VM-CID-CREATE')
      expect(@cloud).to receive(:create_disk).and_return('DISK-CID-CREATE')
      expect(@cloud).to receive(:attach_disk).with('VM-CID-CREATE', 'DISK-CID-CREATE')
      expect(@agent).to receive(:run_task).with(:mount_disk, 'DISK-CID-CREATE').and_return({})
      expect(@agent).to receive(:run_task).with(:stop)
      expect(@agent).to receive(:run_task).with(:apply, spec)
      expect(@agent).to receive(:run_task).with(:start)

      @deployer.create(BOSH_STEMCELL_TGZ, nil)

      expect(@deployer.state.stemcell_cid).to eq('SC-CID-CREATE')
      expect(@deployer.state.vm_cid).to eq('VM-CID-CREATE')
      expect(@deployer.state.disk_cid).to eq('DISK-CID-CREATE')
      expect(load_deployment).to eq(@deployer.state.values)

      expect(@deployer.renderer.total).to eq(@deployer.renderer.index)
    end

    it 'should destroy a Bosh instance' do
      disk_cid = '33'
      @deployer.state.disk_cid = disk_cid
      @deployer.state.stemcell_cid = 'SC-CID-DESTROY'
      @deployer.state.stemcell_name = @deployer.state.stemcell_cid

      @deployer.state.vm_cid = 'VM-CID-DESTROY'

      expect(@agent).to receive(:list_disk).and_return([disk_cid])
      expect(@agent).to receive(:run_task).with(:stop)
      expect(@agent).to receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
      expect(@cloud).to receive(:detach_disk).with('VM-CID-DESTROY', disk_cid)
      expect(@cloud).to receive(:delete_disk).with(disk_cid)
      expect(@cloud).to receive(:delete_vm).with('VM-CID-DESTROY')

      @deployer.destroy

      expect(@deployer.state.stemcell_cid).to be_nil
      expect(@deployer.state.stemcell_name).to be_nil
      expect(@deployer.state.vm_cid).to be_nil
      expect(@deployer.state.disk_cid).to be_nil

      expect(load_deployment).to eq(@deployer.state.values)

      expect(@deployer.renderer.total).to eq(@deployer.renderer.index)
    end

    it 'should update a Bosh instance' do
      allow(@deployer.infrastructure).to receive(:service_ip).and_return('10.0.0.10')
      spec = Psych.load_file(spec_asset('apply_spec_vcloud.yml'))
      disk_cid = '22'
      expect(Bosh::Deployer::Specification).to receive(:load_apply_spec).and_return(spec)
      allow(Bosh::Deployer::Config).to receive(:agent_properties).and_return({})

      allow(@deployer).to receive(:run_command)
      allow(@deployer).to receive(:wait_until_agent_ready)
      allow(@deployer).to receive(:wait_until_director_ready)
      allow(@deployer).to receive(:load_apply_spec).and_return(spec)
      allow(@deployer).to receive(:load_stemcell_manifest).and_return('cloud_properties' => {})
      allow(@deployer.infrastructure).to receive(:persistent_disk_changed?).and_return(false)

      @deployer.state.stemcell_cid = 'SC-CID-UPDATE'
      @deployer.state.vm_cid = 'VM-CID-UPDATE'
      @deployer.state.disk_cid = disk_cid

      expect(@agent).to receive(:run_task).with(:stop)
      expect(@agent).to receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
      expect(@cloud).to receive(:detach_disk).with('VM-CID-UPDATE', disk_cid)
      expect(@cloud).to receive(:delete_vm).with('VM-CID-UPDATE')
      expect(@cloud).to receive(:delete_stemcell).with('SC-CID-UPDATE')
      expect(@cloud).to receive(:create_stemcell).and_return('SC-CID')
      expect(@cloud).to receive(:create_vm).and_return('VM-CID')
      expect(@cloud).to receive(:attach_disk).with('VM-CID', disk_cid)
      expect(@agent).to receive(:run_task).with(:mount_disk, disk_cid).and_return({})
      expect(@agent).to receive(:list_disk).and_return([disk_cid])
      expect(@agent).to receive(:run_task).with(:stop)
      expect(@agent).to receive(:run_task).with(:apply, spec)
      expect(@agent).to receive(:run_task).with(:start)

      @deployer.update(BOSH_STEMCELL_TGZ, nil)

      expect(@deployer.state.stemcell_cid).to eq('SC-CID')
      expect(@deployer.state.vm_cid).to eq('VM-CID')
      expect(@deployer.state.disk_cid).to eq(disk_cid)

      expect(load_deployment).to eq(@deployer.state.values)
    end

    it 'should fail to create a Bosh instance if stemcell CID exists' do
      @deployer.state.stemcell_cid = 'SC-CID'

      expect {
        @deployer.create(BOSH_STEMCELL_TGZ, nil)
      }.to raise_error(Bosh::Cli::CliError)
    end

    it 'should fail to create a Bosh instance if VM CID exists' do
      @deployer.state.vm_cid = 'VM-CID'

      expect {
        @deployer.create(BOSH_STEMCELL_TGZ, nil)
      }.to raise_error(Bosh::Cli::CliError)
    end

    it 'should fail to destroy a Bosh instance unless stemcell CID exists' do
      @deployer.state.vm_cid = 'VM-CID'
      expect(@agent).to receive(:run_task).with(:stop)
      expect(@cloud).to receive(:delete_vm).with('VM-CID')
      expect {
        @deployer.destroy
      }.to raise_error(Bosh::Cli::CliError)
    end

    it 'should fail to destroy a Bosh instance unless VM CID exists' do
      @deployer.state.stemcell_cid = 'SC-CID'
      expect(@agent).to receive(:run_task).with(:stop)
      expect {
        @deployer.destroy
      }.to raise_error(Bosh::Cli::CliError)
    end
  end
end
