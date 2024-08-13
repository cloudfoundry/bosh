require 'spec_helper'

module Bosh
  module Director
    module DeploymentPlan
      module Steps
        describe CreateVmStep do
          subject { CreateVmStep.new(instance_plan, agent_broadcaster, disks, tags, use_existing) }

          let(:use_existing) { false }
          let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
          let(:disks) { [instance.model.managed_persistent_disk_cid].compact }
          let(:cloud_factory) { instance_double(AZCloudFactory) }
          let(:cloud) { instance_double('Bosh::Clouds::ExternalCpi', :request_cpi_api_version= => nil) }
          let(:cpi_api_version) { 1 }
          let(:cloud_wrapper) { Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud, cpi_api_version) }
          let(:deployment) { Models::Deployment.make(name: 'deployment_name') }
          let(:vm_type) { DeploymentPlan::VmType.new('name' => 'fake-vm-type', 'cloud_properties' => cloud_properties) }
          let(:event_manager) { Api::EventManager.new(true) }
          let(:task) { Bosh::Director::Models::Task.make(id: 42, username: 'user') }
          let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
          let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
          let(:env) { DeploymentPlan::Env.new({}) }
          let(:dns_encoder) { instance_double(DnsEncoder) }
          let(:create_vm_response) { ['new-vm-cid', {}, {}] }
          let(:metadata_err) { 'metadata_err' }
          let(:report) { Stages::Report.new }
          let(:delete_vm_step) { instance_double(DeleteVmStep) }
          let(:expected_group) { 'fake-director-name-deployment-name-fake-job' }
          let(:vm_model) { Models::Vm.make(cid: 'new-vm-cid', instance: instance_model, cpi: 'cpi1') }
          let(:tags) { {} }
          let(:availability_zone) { Bosh::Director::DeploymentPlan::AvailabilityZone.new('az-1', {}) }
          let(:cloud_properties) { { 'ram' => '2gb' } }
          let(:network_cloud_properties) { { 'bandwidth' => '5mbps' } }
          let(:variable_set) { Bosh::Director::Models::VariableSet.make(deployment: deployment) }
          let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }
          let(:stemcell_api_version) { nil }

          let(:stemcell_model) do
            Models::Stemcell.make(cid: 'stemcell-id', name: 'fake-stemcell', version: '123', api_version: stemcell_api_version)
          end

          let(:network_settings) do
            Bosh::Director::DeploymentPlan::NetworkSettings.new(
              instance_group.name,
              'deployment_name',
              { 'gateway' => 'name' },
              [reservation],
              {},
              availability_zone,
              5,
              'uuid-1',
              'bosh',
              false,
              false,
            ).to_hash
          end

          let(:update_job) do
            instance_double(
              Jobs::UpdateDeployment,
              username: 'user',
              task_id: task.id,
              event_manager: event_manager,
            )
          end

          let(:instance_model) do
            Models::Instance.make(
              uuid: SecureRandom.uuid,
              index: 5,
              job: 'fake-job',
              deployment: deployment,
              availability_zone: 'az1',
            )
          end

          let(:vm_deleter) do
            vm_deleter = VmDeleter.new(logger, false, false)
            allow(VmDeleter).to receive(:new).and_return(vm_deleter)
            vm_deleter
          end

          let(:deployment_plan) do
            instance_double(DeploymentPlan::Planner, model: deployment, name: 'deployment_name', recreate: false)
          end

          let(:instance_group) do
            Bosh::Director::DeploymentPlan::InstanceGroup.make(
              vm_type: vm_type,
              env: env,
              default_network: { 'gateway' => 'name' },
              stemcell: stemcell,
            )
          end

          let(:expected_groups) do
            [
              'fake-director-name',
              'deployment-name',
              'fake-job',
              'fake-director-name-deployment-name',
              'deployment-name-fake-job',
              'fake-director-name-deployment-name-fake-job',
            ]
          end

          let(:extra_ip) do
            {
              'a' => {
                'ip' => '192.168.1.3',
                'netmask' => '255.255.255.0',
                'cloud_properties' => {},
                'default' => %w[dns gateway],
                'dns' => ['192.168.1.1', '192.168.1.2'],
                'gateway' => '192.168.1.1',
              },
            }
          end

          let(:instance_plan) do
            desired_instance = Bosh::Director::DeploymentPlan::DesiredInstance.new(instance_group)
            network_plan = Bosh::Director::DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)
            Bosh::Director::DeploymentPlan::InstancePlan.new(
              existing_instance: instance_model,
              desired_instance: desired_instance,
              instance: instance,
              network_plans: [network_plan],
              variables_interpolator: nil,
            )
          end

          let(:instance) do
            instance = DeploymentPlan::Instance.create_from_instance_group(
              instance_group,
              5,
              'started',
              deployment,
              {},
              nil,
              logger,
              nil,
            )
            instance.bind_existing_instance_model(instance_model)
            instance
          end

          let(:reservation) do
            subnet = Bosh::Director::DeploymentPlan::DynamicNetworkSubnet.new('dns', network_cloud_properties, ['az-1'])
            network = Bosh::Director::DeploymentPlan::DynamicNetwork.new('name', [subnet], logger)
            reservation = Bosh::Director::DesiredNetworkReservation.new_dynamic(instance_model, network)
            reservation
          end

          let(:stemcell) do
            stemcell_model
            stemcell = DeploymentPlan::Stemcell.parse('name' => 'fake-stemcell', 'version' => '123')
            stemcell.add_stemcell_models
            stemcell
          end

          let(:agent_client) do
            instance_double(
              AgentClient,
              wait_until_ready: nil,
              update_settings: nil,
              apply: nil,
              get_state: nil,
            )
          end

          before do
            allow(deployment).to receive(:last_successful_variable_set).and_return(variable_set)
            allow(Config).to receive(:preferred_cpi_api_version).and_return(1)
            allow(Config).to receive(:current_job).and_return(update_job)
            Config.name = 'fake-director-name'
            Config.max_vm_create_tries = 2
            Config.flush_arp = true
            allow(agent_broadcaster).to receive(:delete_arp_entries)
            allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
            allow(AZCloudFactory).to receive(:create_with_latest_configs).with(deployment).and_return(cloud_factory)
            allow(cloud_factory).to receive(:get_name_for_az).with(instance_model.availability_zone).and_return('cpi1')
            allow(cloud_factory).to receive(:get).with('cpi1', nil).and_return(cloud_wrapper)
            allow(cloud_factory).to receive(:get).with('cpi1').and_return(cloud_wrapper)
            allow(Models::Vm).to receive(:create).and_return(vm_model)
            allow(cloud_wrapper).to receive(:info)
            allow(cloud).to receive(:set_vm_metadata)
            allow(DeleteVmStep).to receive(:new).and_return(delete_vm_step)
            allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
            allow(blobstore).to receive(:validate!)
            allow(blobstore).to receive(:redact_credentials).and_return([])
          end

          it 'sets vm on given report' do
            allow(cloud_wrapper).to receive(:create_vm).and_return(['', {}, {}])
            subject.perform(report)

            expect(report.vm).to eq(vm_model)
          end

          context 'with existing cloud config' do
            let(:non_default_cloud_factory) { instance_double(AZCloudFactory) }
            let(:use_existing) { true }

            let(:stemcell_model_cpi) do
              Models::Stemcell.make(cid: 'old-stemcell-id', name: 'fake-stemcell', version: '123', cpi: 'cpi1')
            end

            let(:stemcell) do
              stemcell_model
              stemcell_model_cpi
              stemcell = DeploymentPlan::Stemcell.parse('name' => 'fake-stemcell', 'version' => '123')
              stemcell.add_stemcell_models
              stemcell
            end

            it 'uses the outdated cloud config from the existing deployment' do
              expect(AZCloudFactory).to receive(:create_from_deployment).and_return(non_default_cloud_factory)
              expect(non_default_cloud_factory).to receive(:get_name_for_az).with('az1').at_least(:once).and_return 'cpi1'
              expect(non_default_cloud_factory).to receive(:get_cpi_aliases).with('cpi1').at_least(:once).and_return ['cpi1']
              expect(non_default_cloud_factory).to receive(:get).with('cpi1').and_return(cloud_wrapper)
              expect(non_default_cloud_factory).to receive(:get).with('cpi1', nil).and_return(cloud_wrapper)
              expect(cloud_wrapper).to receive(:create_vm).with(
                kind_of(String), 'old-stemcell-id', kind_of(Hash), network_settings, kind_of(Array), kind_of(Hash)
              ).and_return(create_vm_response)

              subject.perform(report)
            end

            context 'when cloud-config/azs are not used' do
              let(:instance_model) { Models::Instance.make(uuid: SecureRandom.uuid, index: 5, job: 'fake-job', deployment: deployment, availability_zone: '') }
              let(:vm_model) { Models::Vm.make(cid: 'new-vm-cid', instance: instance_model, cpi: '') }

              it 'uses any cloud config if availability zones are not used, even though requested' do
                expect(non_default_cloud_factory).to receive(:get_name_for_az).at_least(:once).and_return ''
                expect(non_default_cloud_factory).to receive(:get_cpi_aliases).with('').at_least(:once).and_return ['']
                expect(non_default_cloud_factory).to receive(:get).with('').and_return(cloud_wrapper)
                expect(non_default_cloud_factory).to receive(:get).with('', nil).and_return(cloud_wrapper)

                expect(AZCloudFactory).to receive(:create_from_deployment).and_return(non_default_cloud_factory)
                expect(cloud_wrapper).to receive(:create_vm).with(
                  kind_of(String), 'stemcell-id', kind_of(Hash), network_settings, kind_of(Array), kind_of(Hash)
                ).and_return(create_vm_response)

                subject.perform(report)
              end
            end
          end

          it 'should create a vm' do
            expect(cloud_wrapper).to receive(:create_vm).with(
              kind_of(String),
              'stemcell-id', { 'ram' => '2gb' },
              network_settings,
              disks,
              {
                'bosh' => {
                  'group' => expected_group,
                  'groups' => expected_groups,
                }
              }
            ).and_return(create_vm_response)

            expect(agent_client).to receive(:wait_until_ready)
            expect(Models::Vm).to receive(:create).with(hash_including(
              cid: 'new-vm-cid',
              instance: instance_model,
              stemcell_api_version: nil,
              blobstore_config_sha1: Config.blobstore_config_fingerprint,
              nats_config_sha1: Config.nats_config_fingerprint
            ))

            subject.perform(report)
          end

          context 'when there are tags' do
            let(:tags) { { 'mytag' => 'foobar' } }

            it 'includes tags in create_vm' do
              expect(cloud_wrapper).to receive(:create_vm).with(
                kind_of(String),
                'stemcell-id', { 'ram' => '2gb' },
                network_settings,
                disks,
                {
                  'bosh' => {
                    'group' => expected_group,
                    'groups' => expected_groups,
                    'tags' => tags,
                  }
                }
              ).and_return(create_vm_response)
              expect(agent_client).to receive(:wait_until_ready)
              expect(Models::Vm).to receive(:create)
                .with(hash_including(cid: 'new-vm-cid', instance: instance_model, stemcell_api_version: nil))

              subject.perform(report)
            end

            it 'sets vm metadata' do
              expect(cloud_wrapper).to receive(:create_vm).with(
                kind_of(String),
                'stemcell-id',
                kind_of(Hash),
                network_settings,
                disks,
                {
                  'bosh' => {
                    'group' => expected_group,
                    'groups' => expected_groups,
                    'tags' => tags,
                  },
                },
              ).and_return(create_vm_response)

              Timecop.freeze do
                expect(cloud_wrapper).to receive(:set_vm_metadata) do |vm_cid, metadata|
                  expect(vm_cid).to eq('new-vm-cid')
                  expect(metadata).to match(
                    'deployment' => 'deployment_name',
                    'created_at' => Time.new.getutc.strftime('%Y-%m-%dT%H:%M:%SZ'),
                    'job' => 'fake-job',
                    'instance_group' => 'fake-job',
                    'index' => '5',
                    'director' => 'fake-director-name',
                    'id' => instance_model.uuid,
                    'name' => "fake-job/#{instance_model.uuid}",
                    'mytag' => 'foobar',
                  )
                end

                subject.perform(report)
              end
            end
          end

          context 'with a blobstore config' do
            let(:agent_env_hash) do
              {
                'blobstores' => [{
                  'options' => {
                    'my-key' => 'foo',
                    'my-key-id' => 'bar',
                    'allowed-key' => 'baz',
                  },
                }],
              }
            end
            before do
              allow(Config).to receive(:agent_env).and_return(agent_env_hash)
              allow(blobstore).to receive(:redact_credentials).and_return('redacted-credentials')
              # allow(cloud_factory).to receive(:get).with('cpi1', stemcell_api_version).and_return(cloud_wrapper)
            end

            context 'and the blobstore is configured to use signed urls' do
              before do
                allow(blobstore).to receive(:can_sign_urls?).and_return(true)
              end

              it 'validates blobstore configuration' do
                expect(blobstore).to receive(:validate!).with(agent_env_hash['blobstores'].first['options'], anything)
                allow(cloud_wrapper).to receive(:create_vm).and_return(create_vm_response)
                subject.perform(report)
              end

              it 'does not send blobstore credentials to the agent' do
                expect(cloud_wrapper).to receive(:create_vm).with(
                  kind_of(String),
                  'stemcell-id', { 'ram' => '2gb' },
                  network_settings,
                  disks,
                  {
                    'bosh' => {
                      'group' => expected_group,
                      'groups' => expected_groups,
                      'blobstores' => 'redacted-credentials',
                    }
                  }
                ).and_return(create_vm_response)
                subject.perform(report)
              end
            end

            context 'and the agent is unable to use signed urls' do
              before do
                allow(blobstore).to receive(:can_sign_urls?).and_return(false)
              end

              it 'sends blobstore credentials to the agent' do
                expect(cloud_wrapper).to receive(:create_vm).with(
                  kind_of(String),
                  'stemcell-id', { 'ram' => '2gb' },
                  network_settings,
                  disks,
                  {
                    'bosh' => {
                      'group' => expected_group,
                      'groups' => expected_groups,
                      'blobstores' => [
                        'options' => {
                          'my-key' => 'foo',
                          'my-key-id' => 'bar',
                          'allowed-key' => 'baz',
                        },
                      ],
                    }
                  }
                ).and_return(create_vm_response)
                subject.perform(report)
              end
            end
          end

          it 'should record events' do
            expect(cloud_wrapper).to receive(:create_vm).with(
              kind_of(String),
              'stemcell-id', { 'ram' => '2gb' },
              network_settings,
              disks,
              {
                'bosh' => {
                  'group' => expected_group,
                  'groups' => expected_groups,
                }
              }
            ).and_return(create_vm_response)

            expect do
              subject.perform(report)
            end.to change { Models::Event.count }.from(0).to(2)

            event1 = Models::Event.first
            expect(event1.user).to eq('user')
            expect(event1.action).to eq('create')
            expect(event1.object_type).to eq('vm')
            expect(event1.object_name).to eq(nil)
            expect(event1.task).to eq(task.id.to_s)
            expect(event1.deployment).to eq(instance_model.deployment.name)
            expect(event1.instance).to eq(instance_model.name)

            event2 = Models::Event.order(:id).all[1]
            expect(event2.parent_id).to eq(event1.id)
            expect(event2.user).to eq('user')
            expect(event2.action).to eq('create')
            expect(event2.object_type).to eq('vm')
            expect(event2.object_name).to eq('new-vm-cid')
            expect(event2.task).to eq(task.id.to_s)
            expect(event2.deployment).to eq(instance_model.deployment.name)
            expect(event2.instance).to eq(instance_model.name)
          end

          it 'should record events about error' do
            expect(cloud_wrapper).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))
            expect do
              subject.perform(report)
            end.to raise_error Bosh::Clouds::VMCreationFailed

            event2 = Models::Event.order(:id).all[1]
            expect(event2.error).to eq('Bosh::Clouds::VMCreationFailed')
          end

          it 'deletes created VM from cloud on DB failure' do
            expect(cloud_wrapper).to receive(:create_vm).and_return(create_vm_response)
            expect(Bosh::Director::Models::Vm).to receive(:create).and_raise('Bad DB. Bad.')
            expect(vm_deleter).to receive(:delete_vm_by_cid).with('new-vm-cid', nil)
            expect do
              subject.perform(report)
            end.to raise_error 'Bad DB. Bad.'
          end

          it 'flushes the ARP cache' do
            allow(cloud_wrapper).to receive(:create_vm).with(
              kind_of(String),
              'stemcell-id',
              { 'ram' => '2gb' },
              network_settings.merge(extra_ip),
              disks,
              {
                'bosh' => {
                  'group' => expected_group,
                  'groups' => expected_groups,
                },
              },
            ).and_return(create_vm_response)

            allow(instance_plan).to receive(:network_settings_hash).and_return(
              network_settings.merge(extra_ip),
            )

            subject.perform(report)
            expect(agent_broadcaster).to have_received(:delete_arp_entries).with(vm_model.cid, ['192.168.1.3'])
          end

          it 'does not flush the arp cache when arp_flush set to false' do
            Config.flush_arp = false

            allow(cloud_wrapper).to receive(:create_vm).with(
              kind_of(String),
              'stemcell-id',
              { 'ram' => '2gb' },
              network_settings.merge(extra_ip),
              disks,
              {
                'bosh' => {
                  'group' => expected_group,
                  'groups' => expected_groups,
                },
              },
            ).and_return(create_vm_response)

            allow(instance_plan).to receive(:network_settings_hash).and_return(
              network_settings.merge(extra_ip),
            )

            subject.perform(report)
            expect(agent_broadcaster).not_to have_received(:delete_arp_entries).with(vm_model.cid, ['192.168.1.3'])
          end

          context 'when there is a vm creation error' do
            let(:create_vm_response) { ['fake-vm-cid', {}, {}] }
            it 'should retry creating a VM if it is told it is a retryable error' do
              expect(cloud_wrapper).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(true))
              expect(cloud_wrapper).to receive(:create_vm).once.and_return(create_vm_response)

              expect(Models::Vm).to receive(:create).with(hash_including(cid: 'fake-vm-cid', instance: instance_model, stemcell_api_version: nil))

              subject.perform(report)
            end

            it 'should not retry creating a VM if it is told it is not a retryable error' do
              expect(cloud_wrapper).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

              expect { subject.perform(report) }.to raise_error(Bosh::Clouds::VMCreationFailed)
            end

            it 'should try exactly the configured number of times (max_vm_create_tries) when it is a retryable error' do
              Config.max_vm_create_tries = 3

              expect(cloud_wrapper).to receive(:create_vm).exactly(3).times.and_raise(Bosh::Clouds::VMCreationFailed.new(true))

              expect { subject.perform(report) }.to raise_error(Bosh::Clouds::VMCreationFailed)
            end
          end

          it 'should not destroy the VM if the Config.keep_unreachable_vms flag is true' do
            expect(agent_client).to receive(:wait_until_ready).and_raise(metadata_err)
            Config.keep_unreachable_vms = true
            expect(cloud_wrapper).to receive(:create_vm).and_return(create_vm_response)
            expect(cloud_wrapper).to_not receive(:delete_vm)

            expect { subject.perform(report) }.to raise_error(metadata_err)
          end

          it 'should destroy the VM if the Config.keep_unreachable_vms flag is false' do
            expect(agent_client).to receive(:wait_until_ready).and_raise(metadata_err)
            Config.keep_unreachable_vms = false
            expect(cloud_wrapper).to receive(:create_vm).and_return(create_vm_response)
            expect(delete_vm_step).to receive(:perform).with(report)

            expect { subject.perform(report) }.to raise_error(metadata_err)
          end

          it 'should have deep copy of environment' do
            env_id = nil
            # create_vm now expected to return an array, so object response need to transformed into array
            expect(cloud_wrapper).to receive(:create_vm) do |*args|
              env_id = args[5].object_id
              [env_id, {}, {}]
            end

            subject.perform(report)

            expect(cloud_wrapper).to receive(:create_vm) do |*args|
              expect(args[5].object_id).not_to eq(env_id)
              [env_id, {}, {}]
            end

            subject.perform(report)
          end

          context 'nats information' do
            context 'is provided' do
              it 'should NOT include the uri in ENV' do
                Config.nats_uri = 'nats://localhost:1234'

                expect(cloud_wrapper).to receive(:create_vm).with(
                  kind_of(String), 'stemcell-id',
                  kind_of(Hash), network_settings, disks,
                  {
                    'bosh' => {
                      'group' => kind_of(String),
                      'groups' => kind_of(Array),
                    }
                  }
                ).and_return(create_vm_response)
                subject.perform(report)
              end

              context 'when ca is included' do
                let(:cert_generator) { instance_double 'Bosh::Director::NatsClientCertGenerator' }
                let(:cert) { instance_double 'OpenSSL::X509::Certificate' }
                let(:private_key) { instance_double 'OpenSSL::PKey::RSA' }

                before do
                  director_config = SpecHelper.spec_get_director_config
                  allow(Config).to receive(:nats_client_ca_certificate_path).and_return(director_config['nats']['client_ca_certificate_path'])
                  allow(Config).to receive(:nats_client_ca_private_key_path).and_return(director_config['nats']['client_ca_private_key_path'])
                end

                it 'should generate cert with agent ID in ENV' do
                  allow(private_key).to receive(:to_pem).and_return('pkey begin\npkey content\npkey end\n')
                  allow(cert).to receive(:to_pem).and_return('certificate begin\ncertificate content\ncertificate end\n')
                  allow(NatsClientCertGenerator).to receive(:new).and_return(cert_generator)

                  expect(cert_generator).to receive(:generate_nats_client_certificate).with(
                    /^([0-9a-f\-]*)\.bootstrap\.agent\.bosh-internal/,
                  ).and_return(
                    cert: cert,
                    key: private_key,
                  )

                  allow(Config).to receive(:nats_server_ca).and_return('nats begin\nnats content\nnats end\n')

                  expect(cloud_wrapper).to receive(:create_vm).with(
                    kind_of(String), 'stemcell-id',
                    kind_of(Hash), network_settings, disks,
                    {
                      'bosh' => {
                        'mbus' => {
                          'cert' => {
                            'ca' => 'nats begin\nnats content\nnats end\n',
                            'certificate' => 'certificate begin\ncertificate content\ncertificate end\n',
                            'private_key' => 'pkey begin\npkey content\npkey end\n',
                          },
                        },
                        'group' => kind_of(String),
                        'groups' => kind_of(Array),
                      }
                    }
                  ).and_return(create_vm_response)
                  subject.perform(report)
                end
              end
            end

            context 'is NOT provided' do
              it 'should not have the mbus key in ENV' do
                Config.nats_server_ca = nil
                Config.nats_uri = nil

                expect(cloud_wrapper).to receive(:create_vm).with(
                  kind_of(String), 'stemcell-id',
                  kind_of(Hash), network_settings, disks,
                  {
                    'bosh' => {
                      'group' => kind_of(String),
                      'groups' => kind_of(Array),
                    }
                  }
                ).and_return(create_vm_response)
                subject.perform(report)
              end
            end
          end

          context 'Config.generate_vm_passwords flag is true' do
            before do
              Config.generate_vm_passwords = true
            end

            context 'no password is specified' do
              it 'should generate a random VM password' do
                expect(cloud_wrapper).to receive(:create_vm) do |_, _, _, _, _, env|
                  expect(env['bosh']['password'].length).to_not eq(0)
                end.and_return(create_vm_response)

                subject.perform(report)
              end
            end

            context 'password is specified' do
              let(:env) do
                DeploymentPlan::Env.new(
                  'bosh' => { 'password' => 'custom-password' },
                )
              end
              it 'should generate a random VM password' do
                expect(cloud_wrapper).to receive(:create_vm) do |_, _, _, _, _, env|
                  expect(env['bosh']['password']).to eq('custom-password')
                end.and_return(create_vm_response)

                subject.perform(report)
              end
            end
          end

          context 'Config.generate_vm_passwords flag is false' do
            before do
              Config.generate_vm_passwords = false
            end

            context 'no password is specified' do
              it 'should generate a random VM password' do
                expect(cloud_wrapper).to receive(:create_vm) do |_, _, _, _, _, env|
                  expect(env['bosh']).to eq('group' => expected_group, 'groups' => expected_groups)
                end.and_return(create_vm_response)

                subject.perform(report)
              end
            end

            context 'password is specified' do
              let(:env) do
                DeploymentPlan::Env.new(
                  'bosh' => { 'password' => 'custom-password' },
                )
              end

              it 'should generate a random VM password' do
                expect(cloud_wrapper).to receive(:create_vm) do |_, _, _, _, _, env|
                  expect(env['bosh']['password']).to eq('custom-password')
                end.and_return(create_vm_response)

                subject.perform(report)
              end
            end
          end

          context 'cloud_properties, networks_settings, env interpolation' do
            let(:variables_interpolator) { instance_double(Bosh::Director::ConfigServer::VariablesInterpolator) }

            let(:instance_spec) { instance_double('Bosh::Director::DeploymentPlan::InstanceSpec') }

            let(:cloud_properties) do
              {
                'a' => 'bar',
                'b' => '((smurf_placeholder))',
                'c' => '((gargamel_placeholder))',
              }
            end

            let(:resolved_cloud_properties) do
              {
                'a' => 'bar',
                'b' => 'blue',
                'c' => 'green',
              }
            end

            let(:network_cloud_properties) do
              { 'network-v1' => '((find-me))' }
            end

            let(:resolved_network_cloud_properties) do
              { 'network-v1' => 'resolved-name' }
            end

            let(:unresolved_networks_settings) do
              {
                'name' => {
                  'type' => 'dynamic',
                  'cloud_properties' => network_cloud_properties,
                  'dns' => 'dns',
                  'default' => ['gateway'],
                },
              }
            end

            let(:resolved_networks_settings) do
              {
                'name' => {
                  'type' => 'dynamic',
                  'cloud_properties' => resolved_network_cloud_properties,
                  'dns' => 'dns',
                  'default' => ['gateway'],
                },
              }
            end

            let(:user_provided_env_hash) do
              {
                'foo' => 'bar',
                'smurf' => '((smurf_placeholder))',
                'gargamel' => '((gargamel_placeholder))',
                'bosh' => {
                  'value_1_key' => 'value_1_value',
                  'value_2_key' => 'value_2_value',
                  'value_3_key' => {
                    'value_4_key' => 'value_4_value',
                    'value_5_key' => 'value_5_value',
                  },
                  'value_6_key' => {
                    'value_7_key' => 'value_7_value',
                    'value_8_key' => 'value_8_value',
                  },
                },
              }
            end

            let(:env) do
              DeploymentPlan::Env.new(
                user_provided_env_hash,
              )
            end

            let(:agent_env_bosh_hash) do
              {
                'value_1_key' => 'value_1_value_changed',
                'value_6_key' => {
                  'smurf' => 'i am here',
                },
                'a' => '12',
                'b' => {
                  'c' => '34',
                },
              }
            end

            let(:resolved_user_provided_env_hash) do
              {
                'foo' => 'bar',
                'smurf' => 'blue',
                'gargamel' => 'green',
                'bosh' => {
                  'value_1_key' => 'value_1_value',
                  'value_2_key' => 'value_2_value',
                  'value_3_key' => {
                    'value_4_key' => 'value_4_value',
                    'value_5_key' => 'value_5_value',
                  },
                  'value_6_key' => {
                    'value_7_key' => 'value_7_value',
                    'value_8_key' => 'value_8_value',
                  },
                },
              }
            end

            let(:expected_env) do
              {
                'foo' => 'bar',
                'smurf' => 'blue',
                'gargamel' => 'green',
                'bosh' => {
                  'value_1_key' => 'value_1_value',
                  'value_2_key' => 'value_2_value',
                  'value_3_key' => {
                    'value_4_key' => 'value_4_value',
                    'value_5_key' => 'value_5_value',
                  },
                  'value_6_key' => {
                    'value_7_key' => 'value_7_value',
                    'value_8_key' => 'value_8_value',
                  },
                  'a' => '12',
                  'b' => {
                    'c' => '34',
                  },
                  'group' => 'fake-director-name-deployment-name-fake-job',
                  'groups' => ['fake-director-name', 'deployment-name', 'fake-job', 'fake-director-name-deployment-name', 'deployment-name-fake-job', 'fake-director-name-deployment-name-fake-job'],
                },
              }
            end

            let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

            before do
              allow(instance_spec).to receive(:as_apply_spec).and_return({})
              allow(instance_spec).to receive(:full_spec).and_return({})
              allow(instance_spec).to receive(:as_template_spec).and_return({})
              allow(instance_plan).to receive(:spec).and_return(instance_spec)
              allow(ConfigServer::VariablesInterpolator).to receive(:new).and_return(variables_interpolator)
              allow(Config).to receive(:agent_env).and_return(agent_env_bosh_hash)
            end

            it 'should interpolate them correctly, and merge agent env properties with the user provided ones' do
              instance_plan.instance.desired_variable_set = desired_variable_set

              expect(variables_interpolator).to receive(:interpolate_with_versioning).with(user_provided_env_hash, desired_variable_set).and_return(resolved_user_provided_env_hash)
              expect(variables_interpolator).to receive(:interpolate_with_versioning).with(cloud_properties, desired_variable_set).and_return(resolved_cloud_properties)
              expect(variables_interpolator).to receive(:interpolate_with_versioning).with(unresolved_networks_settings, desired_variable_set).and_return(resolved_networks_settings)

              expect(cloud_wrapper).to receive(:create_vm) do |_, _, cloud_properties_param, network_settings_param, _, env_param|
                expect(cloud_properties_param).to eq(resolved_cloud_properties)
                expect(network_settings_param).to eq(resolved_networks_settings)
                expect(env_param).to eq(expected_env)
              end.and_return(create_vm_response)

              subject.perform(report)
            end
          end

          context 'when stemcell has api_version' do
            let(:stemcell_api_version) { 25 }
            let(:stemcell_model) do
              Models::Stemcell.make(cid: 'stemcell-id', name: 'fake-stemcell', version: '123', api_version: stemcell_api_version)
            end

            before do
              expect(cloud_factory).to receive(:get).with('cpi1', stemcell_api_version).and_return(cloud_wrapper)
            end

            it 'should create a cloud_wrapper associated with the stemcell api version' do
              expect(cloud_wrapper).to receive(:create_vm).with(
                kind_of(String),
                'stemcell-id',
                { 'ram' => '2gb' },
                network_settings,
                disks,
                {
                  'bosh' => {
                    'group' => expected_group,
                    'groups' => expected_groups,
                  },
                },
              ).and_return(create_vm_response)

              expect(agent_client).to receive(:wait_until_ready)
              expect(Models::Vm).to receive(:create).with(hash_including(cid: 'new-vm-cid', instance: instance_model))

              subject.perform(report)
            end

            it 'should associate VM with stemcell api version' do
              expect(cloud_wrapper).to receive(:create_vm).with(
                kind_of(String),
                'stemcell-id',
                { 'ram' => '2gb' },
                network_settings,
                disks,
                {
                  'bosh' => {
                    'group' => expected_group,
                    'groups' => expected_groups,
                  },
                },
              ).and_return(create_vm_response)

              expect(agent_client).to receive(:wait_until_ready)
              expect(Models::Vm).to receive(:create).with(hash_including(cid: 'new-vm-cid', instance: instance_model, stemcell_api_version: stemcell_api_version))

              subject.perform(report)
            end

            it 'deletes created VM from cloud on DB failure' do
              expect(cloud_wrapper).to receive(:create_vm).and_return(create_vm_response)
              expect(Bosh::Director::Models::Vm).to receive(:create).and_raise('Bad DB. Bad.')
              expect(vm_deleter).to receive(:delete_vm_by_cid).with('new-vm-cid', stemcell_api_version)
              expect do
                subject.perform(report)
              end.to raise_error 'Bad DB. Bad.'
            end
          end
        end
      end
    end
  end
end
