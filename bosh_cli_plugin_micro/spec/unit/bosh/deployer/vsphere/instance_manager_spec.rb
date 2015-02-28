require 'spec_helper'
require 'bosh/deployer/instance_manager/vsphere'
require 'bosh/deployer/ui_messager'
require 'logger'

module Bosh
  module Deployer
    describe InstanceManager do
      subject(:deployer) { InstanceManager.new(config, 'fake-config-sha1', ui_messager, 'vsphere') }
      let(:ui_messager) { UiMessager.for_deployer }

      let(:config) do
        config = Psych.load_file(spec_asset('test-bootstrap-config.yml'))
        config['dir'] = dir
        config['name'] = 'spec-my-awesome-spec'
        config['logging'] = { 'file' => "#{dir}/bmim.log" }
        Config.configure(config)
      end

      let(:dir) { Dir.mktmpdir('bdim_spec') }
      let(:cloud) { double(:cloud, create_disk: 'fake-disk-cid', disk_provider: disk_provider) }
      let(:disk_provider) { double(:disk_provider, find: double(:disk, size_in_mb: 4096)) }
      let(:agent) { double('Bosh::Agent::HTTPClient') } # Uses method_missing :(
      let(:stemcell_tgz) { 'bosh-instance-1.0.tgz' }
      let(:logger) { instance_double('Logger', debug: nil, info: nil) }

      before do
        allow(Open3).to receive(:capture2e)
                        .and_return(['output', double('Process::Status', exitstatus: 0)])
        allow(config).to receive(:cloud).and_return(cloud)
        allow(config).to receive(:agent_properties).and_return({})
        allow(SecureRandom).to receive(:uuid).and_return('deadbeef')

        allow(MicroboshJobInstance).to receive(:new).and_return(FakeMicroboshJobInstance.new)
        allow(Bosh::Agent::HTTPClient).to receive(:new).and_return agent
      end

      class FakeMicroboshJobInstance
        def render_templates(spec)
          spec
        end
      end

      after do
        deployer.state.destroy
        FileUtils.remove_entry_secure dir
      end

      def load_deployment
        deployments = DeploymentsState.load_from_dir(config.base_dir, logger)
        instances = deployments.deployments['instances']
        instances.detect { |d| d[:name] == deployer.state.name }
      end

      describe '#update' do
        def perform
          deployer.update(stemcell_id, stemcell_archive)
        end

        before { deployer.state.stemcell_cid = 'SC-CID-UPDATE' } # deployed vm

        before do # attached disk
          deployer.state.disk_cid = 'fake-disk-cid'
          allow(agent).to receive_messages(list_disk: ['fake-disk-cid'])
        end

        let(:apply_spec) { YAML.load_file(spec_asset('apply_spec.yml')) }

        before do # ??
          allow(deployer).to receive(:wait_until_agent_ready)
          allow(deployer).to receive(:wait_until_director_ready)
          allow(deployer).to receive_messages(load_stemcell_manifest: {})
        end

        before { cloud.as_null_object }
        before { allow(agent).to receive(:run_task) }

        # rubocop:disable MethodLength
        def self.it_updates_deployed_instance(stemcell_cid, options = {})
          will_create_stemcell = options[:will_create_stemcell]

          context 'when bosh-deployment.yml vm_cid is nil' do
            before { deployer.state.vm_cid = nil }

            it 'does not unmount the disk or detach the disk or delete the vm' do
              expect(agent).not_to receive(:run_task).with(:unmount_disk, anything)
              expect(cloud).not_to receive(:detach_disk)
              expect(cloud).not_to receive(:delete_vm)
              perform
            end

            it 'removes old vm cid from deployed state' do
              expect { perform }.to change { deployer.state.vm_cid }.from(nil)
            end
          end

          context 'when bosh-deployment.yml vm_cid is populated' do
            before { deployer.state.vm_cid = 'fake-old-vm-cid' }

            it 'stops tasks via the agent, unmount the disk, detach the disk, delete the vm' do
              expect(agent).to receive(:run_task).with(:stop)
              expect(agent).to receive(:run_task)
                                   .with(:unmount_disk, 'fake-disk-cid').and_return({})
              expect(cloud).to receive(:detach_disk).with('fake-old-vm-cid', 'fake-disk-cid')
              expect(cloud).to receive(:delete_vm).with('fake-old-vm-cid')
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
              expect(cloud).not_to receive(:delete_stemcell)
              perform
            end

            it 'removes stemcell cid from deployed state' do
              expect { perform }.to change { deployer.state.stemcell_cid }.from(nil)
            end
          end

          context 'when stemcell_cid is populated' do
            before { deployer.state.stemcell_cid = 'fake-old-stemcell-cid' }

            it 'deletes old stemcell' do
              expect(cloud).to receive(:delete_stemcell).with('fake-old-stemcell-cid')
              perform
            end

            it 'removes old stemcell cid from deployed state' do
              expect { perform }.to change {
                deployer.state.stemcell_cid
              }.from('fake-old-stemcell-cid')
            end
          end

          it 'creates stemcell, create vm, attach disk and start tasks via agent' do
            expect(cloud).to receive(:create_stemcell).and_return('SC-CID') if will_create_stemcell
            expect(cloud).to receive(:create_vm).and_return('VM-CID')
            expect(cloud).to receive(:attach_disk).with('VM-CID', 'fake-disk-cid')
            expect(agent).to receive(:run_task).with(:mount_disk, 'fake-disk-cid').and_return({})
            expect(agent).to receive(:list_disk).and_return(['fake-disk-cid'])
            expect(agent).to receive(:run_task).with(:stop)
            expect(agent).to receive(:run_task).with(:apply, apply_spec)
            expect(agent).to receive(:run_task).with(:start)
            perform
          end

          it 'saves deployed vm cid, stemcell cid, disk cid' do
            allow(cloud).to receive_messages(create_vm: 'VM-CID')
            perform
            expect(deployer.state.stemcell_cid).to eq(stemcell_cid)
            expect(deployer.state.vm_cid).to eq('VM-CID')
            expect(deployer.state.disk_cid).to eq('fake-disk-cid')
            expect(load_deployment).to eq(deployer.state.values)
          end
        end

        def self.it_does_not_update_deployed_instance
          it 'does not communicate with an agent of deployed instance' do
            expect(agent).not_to receive(:run_task)
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
            ).each { |a| expect(cloud).not_to receive(a) }
            perform
          end
        end
        # rubocop:enable MethodLength

        def self.it_updates_stemcell_sha1(sha1)
          context 'when the director becomes ready' do
            it 'saves deployed stemcell sha1' do
              expect(deployer).to receive(:wait_until_director_ready).and_return(nil)
              expect { perform }.to change { deployer.state.stemcell_sha1 }.to(sha1)
            end
          end

          context 'when the director does not become ready' do
            it 'resets saved stemcell sha1 because next deploy should not be skipped' do
              error = Exception.new('director-ready-error')
              expect(deployer).to receive(:wait_until_director_ready).and_raise(error)
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
              expect(deployer).to receive(:wait_until_director_ready).and_return(nil)
              expect { perform }.to change { deployer.state.config_sha1 }.to(sha1)
            end
          end

          context 'when the director does not become ready' do
            it 'resets saved config sha1 because next deploy should not be skipped' do
              error = Exception.new('director-ready-error')
              expect(deployer).to receive(:wait_until_director_ready).and_raise(error)
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
          before { allow(stemcell_archive).to receive(:sha1).and_return('fake-stemcell-sha1') }
          let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive') }

          before { allow(cloud).to receive(:create_stemcell).and_return('fake-stemcell-cid') }
          let(:stemcell_id) { 'bosh-instance-1.0.tgz' }

          before { allow(Specification).to receive_messages(load_apply_spec: apply_spec) }

          context 'with the same stemcell and same config' do
            before { deployer.state.stemcell_sha1 = 'fake-stemcell-sha1' }
            before { deployer.state.config_sha1 = 'fake-config-sha1' }
            it_does_not_update_deployed_instance
            it_keeps_stemcell_sha1 'fake-stemcell-sha1'
            it_keeps_config_sha1 'fake-config-sha1'
          end

          context 'with no vm_cid but existing disk_id and same config' do
            before { deployer.state.vm_cid = nil }
            before { deployer.state.config_sha1 = 'fake-config-sha1' }
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

          before { allow(agent).to receive_messages(release_apply_spec: apply_spec) }

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
          allow(cloud).to receive_messages(create_stemcell: 'SC-CID-CREATE')
          allow(cloud).to receive_messages(create_vm: 'VM-CID-CREATE')
          allow(cloud).to receive_messages(create_disk: 'DISK-CID-CREATE')
          allow(cloud).to receive(:attach_disk)

          allow(Bosh::Common).to receive(:retryable).and_yield(1, 'foo')

          allow(agent).to receive(:ping)
          allow(agent).to receive(:run_task)
          allow(Specification).to receive_messages(load_apply_spec: spec)
          allow(HTTPClient).to receive_messages(new: director_http_client)

          allow(deployer).to receive_messages(load_stemcell_manifest: {})
        end

        it 'creates a Bosh instance' do
          expect(cloud).to receive(:attach_disk).with('VM-CID-CREATE', 'DISK-CID-CREATE')
          expect(agent).to receive(:run_task).with(:mount_disk, 'DISK-CID-CREATE').and_return({})
          expect(agent).to receive(:run_task).with(:stop)
          expect(agent).to receive(:run_task).with(:apply, spec)
          expect(agent).to receive(:run_task).with(:start)
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
            expect(agent).to receive(:ping).and_raise(DirectorGatewayError)
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

            allow(agent).to receive(:run_task)
            allow(agent).to receive_messages(list_disk: [disk_cid])

            allow(cloud).to receive(:detach_disk)
            allow(cloud).to receive(:delete_disk)
            allow(cloud).to receive(:delete_vm)
            allow(cloud).to receive(:delete_stemcell)

            deployments_path = File.join(dir, 'bosh-deployments.yml')
            allow(File).to receive(:open).with(deployments_path, 'w').and_yield(deployments_file)
          end

          it 'saves intermediate state to bosh-deployments.yml' do
            expect(deployments_file).to receive(:write).exactly(3).times

            deployer.destroy
          end

          it 'renders 7 things' do
            deployer.destroy

            expect(deployer.renderer.total).to eq 7
          end

          it 'tells the agent to unmount persistent disk and stop' do
            expect(agent).to receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
            expect(agent).to receive(:run_task).with(:stop)

            deployer.destroy
          end

          it 'tells the cloud to remove all trace that it was ever at the crime scene' do
            expect(cloud).to receive(:detach_disk).with('VM-CID', disk_cid)
            expect(cloud).to receive(:delete_disk).with(disk_cid)
            expect(cloud).to receive(:delete_vm).with('VM-CID')
            expect(cloud).to receive(:delete_stemcell).with('STEMCELL-CID')

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
            expect(agent).to receive(:run_task).with(:stop)
            expect(cloud).to receive(:delete_vm).with('VM-CID')
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
            expect(agent).to receive(:run_task).with(:stop)

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
