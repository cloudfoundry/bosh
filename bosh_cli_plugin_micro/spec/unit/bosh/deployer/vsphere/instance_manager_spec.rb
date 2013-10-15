# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh
  module Deployer
    describe InstanceManager do
      let(:dir) { Dir.mktmpdir("bdim_spec") }
      let(:config) do
        config = Psych.load_file(spec_asset('test-bootstrap-config.yml'))
        config['dir'] = dir
        config['name'] = "spec-my-awesome-spec"
        config['logging'] = { 'file' => "#{dir}/bmim.log" }
        config
      end
      let(:cloud) { instance_double('Bosh::Cloud') }
      let(:agent) { double('Bosh::Agent::HTTPClient') } # Uses method_missing :(
      let(:stemcell_tgz) { 'bosh-instance-1.0.tgz' }
      subject(:deployer) { InstanceManager.create(config) }

      before do
        Open3.stub(capture2e: ['output', double('Process::Status', exitstatus: 0)])
        Config.stub(cloud: cloud)
        Config.stub(agent: agent)
        Config.stub(agent_properties: {})
        SecureRandom.stub(uuid: 'deadbeef')
      end

      after do
        deployer.state.destroy
        FileUtils.remove_entry_secure dir
      end

      def load_deployment
        deployer.send(:load_deployments)["instances"].select { |d| d[:name] == deployer.state.name }.first
      end

      describe '#update' do
        it 'updates a Bosh instance' do
          spec = Psych.load_file(spec_asset("apply_spec.yml"))
          Specification.should_receive(:load_apply_spec).and_return(spec)

          disk_cid = "22"
          deployer.stub(:wait_until_agent_ready)
          deployer.stub(:wait_until_director_ready)
          deployer.stub(:load_apply_spec).and_return(spec)
          deployer.stub(:load_stemcell_manifest).and_return({})

          deployer.state.stemcell_cid = "SC-CID-UPDATE"
          deployer.state.vm_cid = "VM-CID-UPDATE"
          deployer.state.disk_cid = disk_cid

          disk = deployer.disk_model.new
          disk.uuid = disk_cid
          disk.size = 4096
          disk.save

          agent.should_receive(:run_task).with(:stop)
          agent.should_receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
          cloud.should_receive(:detach_disk).with("VM-CID-UPDATE", disk_cid)
          cloud.should_receive(:delete_vm).with("VM-CID-UPDATE")
          cloud.should_receive(:delete_stemcell).with("SC-CID-UPDATE")
          cloud.should_receive(:create_stemcell).and_return("SC-CID")
          cloud.should_receive(:create_vm).and_return("VM-CID")
          cloud.should_receive(:attach_disk).with("VM-CID", disk_cid)
          agent.should_receive(:run_task).with(:mount_disk, disk_cid).and_return({})
          agent.should_receive(:list_disk).and_return([disk_cid])
          agent.should_receive(:run_task).with(:stop)
          agent.should_receive(:run_task).with(:apply, spec)
          agent.should_receive(:run_task).with(:start)

          deployer.update(stemcell_tgz)

          deployer.state.stemcell_cid.should == "SC-CID"
          deployer.state.vm_cid.should == "VM-CID"
          deployer.state.disk_cid.should == disk_cid

          load_deployment.should == deployer.state.values
        end
      end

      describe '#create' do
        let(:spec) { Psych.load_file(spec_asset('apply_spec.yml')) }
        let(:director_http_response) { double('Response', status: 200, body: '') }
        let(:director_http_client) { instance_double('HTTPClient', get: director_http_response).as_null_object }

        before do
          cloud.stub(create_stemcell: 'SC-CID-CREATE')
          cloud.stub(create_vm: 'VM-CID-CREATE')
          cloud.stub(create_disk: 'DISK-CID-CREATE')
          cloud.stub(:attach_disk) #.with('VM-CID-CREATE', 'DISK-CID-CREATE')

          Bosh::Common.stub(:retryable).and_yield(1, 'foo')

          agent.stub(:ping)
          agent.stub(:run_task)
          Specification.stub(load_apply_spec: spec)
          HTTPClient.stub(new: director_http_client)

          deployer.stub(load_stemcell_manifest: {})
        end

        it 'creates a Bosh instance' do
          cloud.should_receive(:attach_disk).with('VM-CID-CREATE', 'DISK-CID-CREATE')
          agent.should_receive(:run_task).with(:mount_disk, 'DISK-CID-CREATE').and_return({})
          agent.should_receive(:run_task).with(:stop)
          agent.should_receive(:run_task).with(:apply, spec)
          agent.should_receive(:run_task).with(:start)

          deployer.create(stemcell_tgz)
        end

        it 'goes to 11' do
          deployer.create(stemcell_tgz)

          expect(deployer.renderer.total).to eq 11
        end

        it 'updates the saved state file' do
          deployer.create(stemcell_tgz)

          expect(deployer.state.stemcell_cid).to eq 'SC-CID-CREATE'
          expect(deployer.state.vm_cid).to eq 'VM-CID-CREATE'
          expect(deployer.state.disk_cid).to eq 'DISK-CID-CREATE'
          expect(load_deployment).to eq deployer.state.values
        end

        context 'when unable to connect to agent' do
          it 'provides a nice error' do
            agent.should_receive(:ping).and_raise(DirectorGatewayError)

            expect {
              deployer.create(stemcell_tgz)
            }.to raise_error(Bosh::Cli::CliError, /Unable to connect to Bosh agent/)
          end
        end

        context 'when unable to connect to director' do
          let(:director_http_response) { double('Response', status: 503) }

          it 'provides a nice error' do
            expect {
              deployer.create(stemcell_tgz)
            }.to raise_error(Bosh::Cli::CliError, /Unable to connect to Bosh Director/)
          end
        end

        context 'when stemcell CID exists' do
          before do
            deployer.state.stemcell_cid = 'SC-CID'
          end

          it 'fails to create a Bosh instance' do
            expect {
              deployer.create(stemcell_tgz)
            }.to raise_error(Bosh::Cli::CliError, /stemcell SC-CID already exists/)
          end
        end

        context 'when VM CID exists' do
          before do
            deployer.state.vm_cid = 'VM-CID'
          end

          it 'fails to create a Bosh instance' do
            expect {
              deployer.create(stemcell_tgz)
            }.to raise_error(Bosh::Cli::CliError, /VM VM-CID already exists/)
          end
        end
      end

      describe '#destroy' do

        before do
          deployer.state.stemcell_cid = 'STEMCELL-CID'
          deployer.state.vm_cid = 'VM-CID'
          deployer.state.stemcell_name = File.basename(stemcell_tgz, '.tgz')
        end

        context 'when disk is assigned' do
          let(:disk_cid) { 'vol-333333' }
          let(:deployments_file) { instance_double('File', write: nil) }

          before do
            deployer.state.disk_cid = disk_cid

            agent.stub(:run_task)
            agent.stub(list_disk: [disk_cid])

            cloud.stub(:detach_disk)
            cloud.stub(:delete_disk)
            cloud.stub(:delete_vm)
            cloud.stub(:delete_stemcell)

            File.stub(:open).with(File.join(dir, 'bosh-deployments.yml'), 'w').and_yield(deployments_file)
          end

          it 'saves intermediate state to bosh-deployments.yml' do
            deployments_file.should_receive(:write).exactly(3).times

            deployer.destroy
          end

          it 'renders 7 things' do
            deployer.destroy

            expect(deployer.renderer.total).to eq 7
          end

          it 'tells the agent to unmount persistent disk and stop' do
            agent.should_receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
            agent.should_receive(:run_task).with(:stop)

            deployer.destroy
          end

          it 'tells the cloud to remove all trace that it was ever at the crime scene' do
            cloud.should_receive(:detach_disk).with('VM-CID', disk_cid)
            cloud.should_receive(:delete_disk).with(disk_cid)
            cloud.should_receive(:delete_vm).with('VM-CID')
            cloud.should_receive(:delete_stemcell).with('STEMCELL-CID')

            deployer.destroy
          end

          it 'unsets the stemcell, vm, and disk CIDs from the state' do
            deployer.destroy

            expect(deployer.state.stemcell_cid).to be_nil
            expect(deployer.state.vm_cid).to be_nil
            expect(deployer.state.disk_cid).to be_nil
          end
        end

        #context 'when disk is not assigned'

        context 'when stemcell CID does not exists' do
          before do
            deployer.state.stemcell_cid = nil
          end

          it 'should fail to destroy a Bosh instance' do
            agent.should_receive(:run_task).with(:stop)
            cloud.should_receive(:delete_vm).with('VM-CID')
            expect {
              deployer.destroy
            }.to raise_error(Bosh::Cli::CliError, /Cannot find existing stemcell/)
          end
        end

        context 'when the VM CID is not set in the state' do
          before do
            deployer.state.vm_cid = nil
          end

          it 'fails to destroy a Bosh instance and tells the agent to stop' do
            agent.should_receive(:run_task).with(:stop)

            expect {
              deployer.destroy
            }.to raise_error(Bosh::Cli::CliError, /Cannot find existing VM/)
          end
        end
      end
    end
  end
end