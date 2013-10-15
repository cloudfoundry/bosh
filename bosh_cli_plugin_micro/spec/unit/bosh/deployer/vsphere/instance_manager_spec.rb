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
        def perform
          deployer.update(stemcell_id, stemcell_archive)
        end

        let(:stemcell_id) { 'bosh-instance-1.0.tgz' }

        before do # deployed vm
          deployer.state.vm_cid = 'VM-CID-UPDATE'
          deployer.state.stemcell_cid = 'SC-CID-UPDATE'
        end

        before do # attached disk
          deployer.state.disk_cid = 'fake-disk-cid'
          agent.stub(list_disk: ['fake-disk-cid'])
          deployer.disk_model.delete
          deployer.disk_model.create(uuid: 'fake-disk-cid', size: 4096)
        end

        let(:apply_spec) { YAML.load_file(spec_asset("apply_spec.yml")) }
        before { Specification.stub(load_apply_spec: apply_spec) }

        before do # ??
          deployer.stub(:wait_until_agent_ready)
          deployer.stub(:wait_until_director_ready)
          deployer.stub(load_stemcell_manifest: {})
        end

        before { cloud.as_null_object }
        before { agent.stub(:run_task) }

        def self.it_updates_deployed_instance
          it 'updates deployed instance' do
            agent.should_receive(:run_task).with(:stop)
            agent.should_receive(:run_task).with(:unmount_disk, 'fake-disk-cid').and_return({})
            cloud.should_receive(:detach_disk).with('VM-CID-UPDATE', 'fake-disk-cid')
            cloud.should_receive(:delete_vm).with('VM-CID-UPDATE')
            cloud.should_receive(:delete_stemcell).with('SC-CID-UPDATE')
            cloud.should_receive(:create_stemcell).and_return('SC-CID')
            cloud.should_receive(:create_vm).and_return('VM-CID')
            cloud.should_receive(:attach_disk).with('VM-CID', 'fake-disk-cid')
            agent.should_receive(:run_task).with(:mount_disk, 'fake-disk-cid').and_return({})
            agent.should_receive(:list_disk).and_return(['fake-disk-cid'])
            agent.should_receive(:run_task).with(:stop)
            agent.should_receive(:run_task).with(:apply, apply_spec)
            agent.should_receive(:run_task).with(:start)
            perform
          end

          it 'saves deployed vm, stemcell cids' do
            cloud.stub(create_vm: 'VM-CID', create_stemcell: 'SC-CID')
            perform
            expect(deployer.state.stemcell_cid).to eq('SC-CID')
            expect(deployer.state.vm_cid).to eq('VM-CID')
            expect(deployer.state.disk_cid).to eq('fake-disk-cid')
            expect(load_deployment).to eq(deployer.state.values)
          end
        end

        context 'when stemcell archive is provided' do
          let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive') }
          before { stemcell_archive.stub(sha1: 'fake-stemcell-sha1') }

          context 'with a different stemcell (determined via sha1 difference)' do
            before { deployer.state.stemcell_sha1 = 'fake-different-stemcell-sha1' }

            it_updates_deployed_instance

            it 'saves deployed stemcell sha1' do
              perform
              expect(deployer.state.stemcell_sha1).to eq('fake-stemcell-sha1')
            end
          end

          context 'with the same stemcell (determined via sha1 equality)' do
            before { deployer.state.stemcell_sha1 = 'fake-stemcell-sha1' }

            it 'does not communicate with an agent of deployed instance' do
              agent.should_not_receive(:run_task)
              perform
            end

            it 'does not use cpi actions to update deployed instance' do
              cloud_actions = %w(detach_disk delete_vm delete_stemcell create_stemcell create_vm attach_disk)
              cloud_actions.each { |a| cloud.should_not_receive(a) }
              perform
            end

            it 'keeps same stemcell sha1 which is same as before' do
              perform
              expect(deployer.state.stemcell_sha1).to eq('fake-stemcell-sha1')
            end
          end

          context "when previously used stemcell's sha1 was not recorded " +
                  "(before quick update feature was introduced)" do
            before { deployer.state.stemcell_sha1 = nil }

            it_updates_deployed_instance

            it 'saves deployed stemcell sha1' do
              perform
              expect(deployer.state.stemcell_sha1).to eq('fake-stemcell-sha1')
            end
          end
        end

        context 'when stemcell archive is not provided' do
          let(:stemcell_archive) { nil }

          it_updates_deployed_instance

          it 'does not save deployed stemcell sha1 ' +
             'because sha1 can only be obtained from full stemcell archive' do
            perform
            expect(deployer.state.stemcell_sha1).to be_nil
          end
        end
      end

      describe '#create' do
        let(:spec) { Psych.load_file(spec_asset('apply_spec.yml')) }
        let(:director_http_response) { double('Response', status: 200, body: '') }
        let(:director_http_client) { instance_double('HTTPClient', get: director_http_response).as_null_object }

        def perform
          deployer.create(stemcell_tgz, nil)
        end

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
          perform
        end

        it 'goes to 11' do
          perform
          expect(deployer.renderer.total).to eq 11
        end

        it 'updates the saved state file' do
          perform
          expect(deployer.state.stemcell_cid).to eq 'SC-CID-CREATE'
          expect(deployer.state.vm_cid).to eq 'VM-CID-CREATE'
          expect(deployer.state.disk_cid).to eq 'DISK-CID-CREATE'
          expect(load_deployment).to eq deployer.state.values
        end

        context 'when unable to connect to agent' do
          it 'provides a nice error' do
            agent.should_receive(:ping).and_raise(DirectorGatewayError)
            expect { perform }.to raise_error(
              Bosh::Cli::CliError, /Unable to connect to Bosh agent/)
          end
        end

        context 'when unable to connect to director' do
          let(:director_http_response) { double('Response', status: 503) }

          it 'provides a nice error' do
            expect { perform }.to raise_error(
              Bosh::Cli::CliError, /Unable to connect to Bosh Director/)
          end
        end

        context 'when stemcell CID exists' do
          before { deployer.state.stemcell_cid = 'SC-CID' }

          it 'fails to create a Bosh instance' do
            expect { perform }.to raise_error(
              Bosh::Cli::CliError, /stemcell SC-CID already exists/)
          end
        end

        context 'when VM CID exists' do
          before { deployer.state.vm_cid = 'VM-CID' }

          it 'fails to create a Bosh instance' do
            expect { perform }.to raise_error(
              Bosh::Cli::CliError, /VM VM-CID already exists/)
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