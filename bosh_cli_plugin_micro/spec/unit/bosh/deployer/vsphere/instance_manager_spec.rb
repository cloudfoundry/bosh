require 'spec_helper'
require 'bosh/deployer/instance_manager/vsphere'
require 'bosh/deployer/ui_messager'

module Bosh
  module Deployer
    describe InstanceManager do
      subject(:deployer) { InstanceManager::Vsphere.new(config, 'fake-config-sha1', ui_messager) }
      let(:ui_messager) { UiMessager.for_deployer }
      let(:config) do
        config = Psych.load_file(spec_asset('test-bootstrap-config.yml'))
        config['dir'] = dir
        config['name'] = 'spec-my-awesome-spec'
        config['logging'] = { 'file' => "#{dir}/bmim.log" }
        config
      end

      let(:dir) { Dir.mktmpdir('bdim_spec') }
      let(:cloud) { instance_double('Bosh::Cloud') }
      let(:agent) { double('Bosh::Agent::HTTPClient') } # Uses method_missing :(
      let(:stemcell_tgz) { 'bosh-instance-1.0.tgz' }

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
        instances = deployer.send(:load_deployments)['instances']
        instances.detect { |d| d[:name] == deployer.state.name }
      end

      describe '#update' do
        def perform
          deployer.update(stemcell_id, stemcell_archive)
        end

        before { deployer.state.stemcell_cid = 'SC-CID-UPDATE' } # deployed vm

        before do # attached disk
          deployer.state.disk_cid = 'fake-disk-cid'
          agent.stub(list_disk: ['fake-disk-cid'])
          deployer.disk_model.delete
          deployer.disk_model.create(uuid: 'fake-disk-cid', size: 4096)
        end

        let(:apply_spec) { YAML.load_file(spec_asset('apply_spec.yml')) }

        before do # ??
          deployer.stub(:wait_until_agent_ready)
          deployer.stub(:wait_until_director_ready)
          deployer.stub(load_stemcell_manifest: {})
        end

        before { cloud.as_null_object }
        before { agent.stub(:run_task) }

        # rubocop:disable MethodLength
        def self.it_updates_deployed_instance(stemcell_cid, options = {})
          will_create_stemcell = options[:will_create_stemcell]

          context 'when bosh-deployment.yml vm_cid is nil' do
            before { deployer.state.vm_cid = nil }

            it 'does not unmount the disk or detach the disk or delete the vm' do
              agent.should_not_receive(:run_task).with(:unmount_disk, anything)
              cloud.should_not_receive(:detach_disk)
              cloud.should_not_receive(:delete_vm)
              perform
            end

            it 'removes old vm cid from deployed state' do
              expect { perform }.to change { deployer.state.vm_cid }.from(nil)
            end
          end

          context 'when bosh-deployment.yml vm_cid is populated' do
            before { deployer.state.vm_cid = 'fake-old-vm-cid' }

            it 'stops tasks via the agent, unmount the disk, detach the disk, delete the vm' do
              agent.should_receive(:run_task).with(:stop)
              agent.should_receive(:run_task).with(:unmount_disk, 'fake-disk-cid').and_return({})
              cloud.should_receive(:detach_disk).with('fake-old-vm-cid', 'fake-disk-cid')
              cloud.should_receive(:delete_vm).with('fake-old-vm-cid')
              perform
            end

            it 'removes old vm cid from deployed state' do
              expect { perform }.to change {
                deployer.state.vm_cid
              }.from('fake-old-vm-cid')
            end
          end

          context 'when stemcell_cid is nil' do
            before { deployer.state.stemcell_cid = nil }

            it 'does not delete old stemcell' do
              cloud.should_not_receive(:delete_stemcell)
              perform
            end

            it 'removes stemcell cid from deployed state' do
              expect { perform }.to change { deployer.state.stemcell_cid }.from(nil)
            end
          end

          context 'when stemcell_cid is populated' do
            before { deployer.state.stemcell_cid = 'fake-old-stemcell-cid' }

            it 'deletes old stemcell' do
              cloud.should_receive(:delete_stemcell).with('fake-old-stemcell-cid')
              perform
            end

            it 'removes old stemcell cid from deployed state' do
              expect { perform }.to change {
                deployer.state.stemcell_cid
              }.from('fake-old-stemcell-cid')
            end
          end

          it 'creates stemcell, create vm, attach disk and start tasks via agent' do
            cloud.should_receive(:create_stemcell).and_return('SC-CID') if will_create_stemcell
            cloud.should_receive(:create_vm).and_return('VM-CID')
            cloud.should_receive(:attach_disk).with('VM-CID', 'fake-disk-cid')
            agent.should_receive(:run_task).with(:mount_disk, 'fake-disk-cid').and_return({})
            agent.should_receive(:list_disk).and_return(['fake-disk-cid'])
            agent.should_receive(:run_task).with(:stop)
            agent.should_receive(:run_task).with(:apply, apply_spec)
            agent.should_receive(:run_task).with(:start)
            perform
          end

          it 'saves deployed vm cid, stemcell cid, disk cid' do
            cloud.stub(create_vm: 'VM-CID')
            perform
            expect(deployer.state.stemcell_cid).to eq(stemcell_cid)
            expect(deployer.state.vm_cid).to eq('VM-CID')
            expect(deployer.state.disk_cid).to eq('fake-disk-cid')
            expect(load_deployment).to eq(deployer.state.values)
          end
        end

        def self.it_does_not_update_deployed_instance
          it 'does not communicate with an agent of deployed instance' do
            agent.should_not_receive(:run_task)
            perform
          end

          it 'does not use cpi actions to update deployed instance' do
            %w(
              detach_disk
              delete_vm
              delete_stemcell
              create_stemcell
              create_vm
              attach_disk
            ).each { |a| cloud.should_not_receive(a) }
            perform
          end
        end
        # rubocop:enable MethodLength

        def self.it_updates_stemcell_sha1(sha1)
          context 'when the director becomes ready' do
            it 'saves deployed stemcell sha1' do
              deployer.should_receive(:wait_until_director_ready).and_return(nil)
              expect { perform }.to change { deployer.state.stemcell_sha1 }.to(sha1)
            end
          end

          context 'when the director does not become ready' do
            it 'resets saved stemcell sha1 because next deploy should not be skipped' do
              error = Exception.new('director-ready-error')
              deployer.should_receive(:wait_until_director_ready).and_raise(error)
              expect { perform }.to raise_error(error) # rescue propagated error
              expect(deployer.state.stemcell_sha1).to be_nil
            end
          end
        end

        def self.it_keeps_stemcell_sha1(sha1)
          it 'keeps same stemcell sha1 which is same as before' do
            expect { perform }.to_not change {
              deployer.state.stemcell_sha1
            }.from(sha1)
          end
        end

        def self.it_updates_config_sha1(sha1)
          context 'when the director becomes ready' do
            it 'saves deployed config sha1' do
              deployer.should_receive(:wait_until_director_ready).and_return(nil)
              expect { perform }.to change { deployer.state.config_sha1 }.to(sha1)
            end
          end

          context 'when the director does not become ready' do
            it 'resets saved config sha1 because next deploy should not be skipped' do
              error = Exception.new('director-ready-error')
              deployer.should_receive(:wait_until_director_ready).and_raise(error)
              expect { perform }.to raise_error(error) # rescue propagated error
              expect(deployer.state.config_sha1).to be_nil
            end
          end
        end

        def self.it_keeps_config_sha1(sha1)
          it 'keeps same config sha1 which is same as before' do
            expect { perform }.to_not change {
              deployer.state.config_sha1
            }.from(sha1)
          end
        end

        context 'when stemcell archive is provided(it includes sha1 in the stemcell.MF)' do
          before { stemcell_archive.stub(sha1: 'fake-stemcell-sha1') }
          let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive') }

          before { cloud.stub(create_stemcell: 'fake-stemcell-cid') }
          let(:stemcell_id) { 'bosh-instance-1.0.tgz' }

          before { Specification.stub(load_apply_spec: apply_spec) }

          context 'with the same stemcell and same config' do
            before { deployer.state.stemcell_sha1 = 'fake-stemcell-sha1' }
            before { deployer.state.config_sha1 = 'fake-config-sha1' }
            it_does_not_update_deployed_instance
            it_keeps_stemcell_sha1 'fake-stemcell-sha1'
            it_keeps_config_sha1 'fake-config-sha1'
          end

          context 'with no vm_cid but existing disk_id and same config' do
            before { deployer.state.vm_cid = nil }
            it_updates_deployed_instance 'fake-stemcell-cid', will_create_stemcell: true
            it_updates_stemcell_sha1 'fake-stemcell-sha1'
            it_keeps_config_sha1 'fake-config-sha1'
          end

          context 'with a different stemcell (determined via sha1 difference) and same config' do
            before { deployer.state.stemcell_sha1 = 'fake-different-stemcell-sha1' }
            before { deployer.state.config_sha1 = 'fake-config-sha1' }
            it_updates_deployed_instance 'fake-stemcell-cid', will_create_stemcell: true
            it_updates_stemcell_sha1 'fake-stemcell-sha1'
            it_keeps_config_sha1 'fake-config-sha1'
          end

          context 'with a same stemcell and different config' do
            before { deployer.state.stemcell_sha1 = 'fake-stemcell-sha1' }
            before { deployer.state.config_sha1 = 'fake-different-config-sha1' }
            it_updates_deployed_instance 'fake-stemcell-cid', will_create_stemcell: true
            it_keeps_stemcell_sha1 'fake-stemcell-sha1'
            it_updates_config_sha1 'fake-config-sha1'
          end

          context 'with a different stemcell and different config' do
            before { deployer.state.stemcell_sha1 = 'fake-different-stemcell-sha1' }
            before { deployer.state.config_sha1 = 'fake-different-config-sha1' }
            it_updates_deployed_instance 'fake-stemcell-cid', will_create_stemcell: true
            it_updates_stemcell_sha1 'fake-stemcell-sha1'
            it_updates_config_sha1 'fake-config-sha1'
          end

          context "when previously used stemcell's sha1 and config's sha were not recorded " +
                  '(before quick update feature was introduced)' do
            before { deployer.state.stemcell_sha1 = nil }
            before { deployer.state.config_sha1 = nil }
            it_updates_deployed_instance 'fake-stemcell-cid', will_create_stemcell: true
            it_updates_stemcell_sha1 'fake-stemcell-sha1'
            it_updates_config_sha1 'fake-config-sha1'
          end
        end

        context 'when stemcell archive is not provided but only ami id is given' do
          let(:stemcell_archive) { nil }
          let(:stemcell_id) { 'fake-ami-id' }

          before { agent.stub(release_apply_spec: apply_spec) }

          context 'with the same stemcell and same config' do
            before { deployer.state.stemcell_sha1 = 'fake-ami-id' }
            before { deployer.state.config_sha1 = 'fake-config-sha1' }
            it_does_not_update_deployed_instance
            it_keeps_stemcell_sha1 'fake-ami-id'
            it_keeps_config_sha1 'fake-config-sha1'
          end

          context 'with a different stemcell (i.e. different stemcell id) and same config' do
            before { deployer.state.stemcell_sha1 = 'fake-different-ami-id' }
            before { deployer.state.config_sha1 = 'fake-config-sha1' }
            it_updates_deployed_instance 'fake-ami-id', will_create_stemcell: false
            it_updates_stemcell_sha1 'fake-ami-id'
            it_keeps_config_sha1 'fake-config-sha1'
          end

          context 'with a same stemcell and different config' do
            before { deployer.state.stemcell_sha1 = 'fake-ami-id' }
            before { deployer.state.config_sha1 = 'fake-different-config-sha1' }
            it_updates_deployed_instance 'fake-ami-id', will_create_stemcell: false
            it_keeps_stemcell_sha1 'fake-ami-id'
            it_updates_config_sha1 'fake-config-sha1'
          end

          context 'with a different stemcell and different config' do
            before { deployer.state.stemcell_sha1 = 'fake-different-ami-id' }
            before { deployer.state.config_sha1 = 'fake-different-config-sha1' }
            it_updates_deployed_instance 'fake-ami-id', will_create_stemcell: false
            it_updates_stemcell_sha1 'fake-ami-id'
            it_updates_config_sha1 'fake-config-sha1'
          end

          context "when previously used stemcell and config's sha were not recorded " +
                  '(before quick update feature was introduced)' do
            before { deployer.state.stemcell_sha1 = nil }
            before { deployer.state.config_sha1 = nil }
            it_updates_deployed_instance 'fake-ami-id', will_create_stemcell: false
            it_updates_stemcell_sha1 'fake-ami-id'
            it_updates_config_sha1 'fake-config-sha1'
          end
        end
      end

      describe '#create' do
        let(:spec) { Psych.load_file(spec_asset('apply_spec.yml')) }
        let(:director_http_response) { double('Response', status: 200, body: '') }

        let(:director_http_client) do
          instance_double(
            'HTTPClient',
            get: director_http_response,
            ssl_config: ssl_config,
          ).as_null_object
        end

        let(:ssl_config) do
          instance_double(
            'HTTPClient::SSLConfig',
            :verify_mode= => nil,
            :verify_callback= => nil,
          )
        end

        def perform
          deployer.create(stemcell_tgz, nil)
        end

        before do
          cloud.stub(create_stemcell: 'SC-CID-CREATE')
          cloud.stub(create_vm: 'VM-CID-CREATE')
          cloud.stub(create_disk: 'DISK-CID-CREATE')
          cloud.stub(:attach_disk)

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

            deployments_path = File.join(dir, 'bosh-deployments.yml')
            File.stub(:open).with(deployments_path, 'w').and_yield(deployments_file)
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

      describe '#exists?' do
        before do
          deployer.state.vm_cid = nil
          deployer.state.stemcell_cid = nil
          deployer.state.disk_cid = nil
        end

        context 'all deployer resources are nil' do
          it 'is false' do
            expect(subject.exists?).to be(false)
          end
        end

        context 'only vm_cid is populated' do
          it 'is true' do
            deployer.state.vm_cid = 'fake-vm-id'
            expect(subject.exists?).to be(true)
          end
        end

        context 'only stemcell_cid is populated' do
          it 'is true' do
            deployer.state.stemcell_cid = 'fake-stemcell-cid'
            expect(subject.exists?).to be(true)
          end
        end

        context 'only disk_cid is populated' do
          it 'is true' do
            deployer.state.disk_cid = 'fake-disk-cid'
            expect(subject.exists?).to be(true)
          end
        end
      end
    end
  end
end
