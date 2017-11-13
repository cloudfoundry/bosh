require 'spec_helper'
require 'timecop'

module Bosh
  module Director
    describe VmCreator do
      subject { VmCreator.new(
        logger, vm_deleter, disk_manager, template_blob_cache, dns_encoder, agent_broadcaster
      ) }

      let(:disk_manager) { DiskManager.new(logger) }
      let(:cloud) { instance_double('Bosh::Cloud') }
      let(:cloud_factory) { instance_double(CloudFactory) }
      let(:vm_deleter) { VmDeleter.new(logger, false, false) }
      let(:template_blob_cache) { instance_double(Bosh::Director::Core::Templates::TemplateBlobCache) }
      let(:agent_broadcaster) { instance_double(AgentBroadcaster) }
      let(:agent_client) do
        instance_double(
          AgentClient,
          wait_until_ready: nil,
          update_settings: nil,
          apply: nil,
          get_state: nil
        )
      end
      let(:network_settings) { BD::DeploymentPlan::NetworkSettings.new(instance_group.name, 'deployment_name', {'gateway' => 'name'}, [reservation], {}, availability_zone, 5, 'uuid-1', 'bosh', false).to_hash }
      let(:deployment) { Models::Deployment.make(name: 'deployment_name') }
      let(:deployment_plan) do
        instance_double(DeploymentPlan::Planner, model: deployment, name: 'deployment_name', recreate: false)
      end
      let(:availability_zone) do
        BD::DeploymentPlan::AvailabilityZone.new('az-1', {})
      end
      let(:cloud_properties) { {'ram' => '2gb'} }
      let(:network_cloud_properties) { {'bandwidth' => '5mbps'} }
      let(:vm_type) { DeploymentPlan::VmType.new({'name' => 'fake-vm-type', 'cloud_properties' => cloud_properties}) }
      let(:stemcell_model) { Models::Stemcell.make(:cid => 'stemcell-id', name: 'fake-stemcell', version: '123') }
      let(:stemcell) do
        stemcell_model
        stemcell = DeploymentPlan::Stemcell.parse({'name' => 'fake-stemcell', 'version' => '123'})
        stemcell.add_stemcell_models
        stemcell
      end
      let(:env) { DeploymentPlan::Env.new({}) }
      let(:dns_encoder) { instance_double(DnsEncoder) }

      let(:instance) do
        instance = DeploymentPlan::Instance.create_from_instance_group(
          instance_group,
          5,
          'started',
          deployment,
          {},
          nil,
          logger
        )
        instance.bind_existing_instance_model(instance_model)
        instance
      end
      let(:reservation) do
        subnet = BD::DeploymentPlan::DynamicNetworkSubnet.new('dns', network_cloud_properties, ['az-1'])
        network = BD::DeploymentPlan::DynamicNetwork.new('name', [subnet], logger)
        reservation = BD::DesiredNetworkReservation.new_dynamic(instance_model, network)
      end
      let(:instance_plan) do
        desired_instance = BD::DeploymentPlan::DesiredInstance.new(instance_group, {}, nil)
        network_plan = BD::DeploymentPlan::NetworkPlanner::Plan.new(reservation: reservation)
        BD::DeploymentPlan::InstancePlan.new(existing_instance: instance_model, desired_instance: desired_instance, instance: instance, network_plans: [network_plan])
      end

      let(:tags) do
        {
          'mytag' => 'foobar'
        }
      end

      let(:instance_group) do
        template_model = BD::Models::Template.make
        job = BD::DeploymentPlan::Job.new(nil, 'fake-job-name', deployment.name)
        job.bind_existing_model(template_model)

        instance_group = BD::DeploymentPlan::InstanceGroup.new(logger)
        instance_group.name = 'fake-job'
        instance_group.vm_type = vm_type
        instance_group.stemcell = stemcell
        instance_group.env = env
        instance_group.jobs << job
        instance_group.default_network = {'gateway' => 'name'}
        instance_group.update = BD::DeploymentPlan::UpdateConfig.new({'canaries' => 1, 'max_in_flight' => 1, 'canary_watch_time' => '1000-2000', 'update_watch_time' => '1000-2000'})
        instance_group.persistent_disk_collection = DeploymentPlan::PersistentDiskCollection.new(logger)
        instance_group
      end

      let(:extra_ip) do
        {
          'a' => {
            'ip' => '192.168.1.3',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {},
            'default' => ['dns', 'gateway'],
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'gateway' => '192.168.1.1'
          }}
      end

      let(:instance_model) { Models::Instance.make(uuid: SecureRandom.uuid, index: 5, job: 'fake-job', deployment: deployment, availability_zone: 'az1') }

      let(:event_manager) { Api::EventManager.new(true)}
      let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}
      let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
      let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}
      let(:update_job) {instance_double(Jobs::UpdateDeployment, username: 'user', task_id: task.id, event_manager: event_manager)}

      let(:global_network_resolver) { instance_double(DeploymentPlan::GlobalNetworkResolver, reserved_ranges: Set.new) }
      let(:networks) { {'my-manual-network' => manual_network} }
      let(:manual_network_spec) {
        {
          'name' => 'my-manual-network',
          'subnets' => [
            {
              'range' => '192.168.1.0/30',
              'gateway' => '192.168.1.1',
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'static' => [],
              'reserved' => [],
              'cloud_properties' => {},
              'az' => 'az-1',
            },
            {
              'range' => '192.168.2.0/30',
              'gateway' => '192.168.2.1',
              'dns' => ['192.168.2.1', '192.168.2.2'],
              'static' => [],
              'reserved' => [],
              'cloud_properties' => {},
              'az' => 'az-2',
            },
            {
              'range' => '192.168.3.0/30',
              'gateway' => '192.168.3.1',
              'dns' => ['192.168.3.1', '192.168.3.2'],
              'static' => [],
              'reserved' => [],
              'cloud_properties' => {},
              'azs' => ['az-2'],
            }

          ]
        }
      }
      let(:manual_network) do
        DeploymentPlan::ManualNetwork.parse(
          manual_network_spec,
          [
            BD::DeploymentPlan::AvailabilityZone.new('az-1', {}),
            BD::DeploymentPlan::AvailabilityZone.new('az-2', {})
          ],
          global_network_resolver,
          logger
        )
      end
      let(:ip_repo) { DeploymentPlan::InMemoryIpRepo.new(logger) }
      let(:ip_provider) { DeploymentPlan::IpProvider.new(ip_repo, networks, logger) }

      let(:expected_groups) {
        [
          'fake-director-name',
          'deployment-name',
          'fake-job',
          'fake-director-name-deployment-name',
          'deployment-name-fake-job',
          'fake-director-name-deployment-name-fake-job'
        ]
      }

      let(:expected_group) { 'fake-director-name-deployment-name-fake-job' }

      before do
        fake_app

        allow(Config).to receive(:cloud).and_return(cloud)
        Config.name = 'fake-director-name'
        Config.max_vm_create_tries = 2
        Config.flush_arp = true
        allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
        allow(JobRenderer).to receive(:render_job_instances_with_cache).with([instance_plan], template_blob_cache, dns_encoder, logger)
        allow(agent_broadcaster).to receive(:delete_arp_entries)
        allow(Config).to receive(:current_job).and_return(update_job)
        allow(Config.cloud).to receive(:delete_vm)
        allow(CloudFactory).to receive(:create_with_latest_configs).and_return(cloud_factory)
        allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
        allow(cloud_factory).to receive(:get_name_for_az).with(instance_model.availability_zone).and_return('cpi1')
        allow(cloud_factory).to receive(:get).with('cpi1').and_return(cloud)
      end

      context 'with existing cloud config' do
        let(:non_default_cloud_factory) { instance_double(CloudFactory) }
        let(:stemcell_model_cpi) { Models::Stemcell.make(:cid => 'old-stemcell-id', name: 'fake-stemcell', version: '123', :cpi => 'cpi1') }
        let(:stemcell) do
          stemcell_model
          stemcell_model_cpi
          stemcell = DeploymentPlan::Stemcell.parse({'name' => 'fake-stemcell', 'version' => '123'})
          stemcell.add_stemcell_models
          stemcell
        end

        it 'uses the outdated cloud config from the existing deployment' do
          expect(CloudFactory).to receive(:create_from_deployment).and_return(non_default_cloud_factory)
          expect(non_default_cloud_factory).to receive(:get_name_for_az).with('az1').at_least(:once).and_return 'cpi1'
          expect(non_default_cloud_factory).to receive(:get).with('cpi1').at_least(:once).and_return(cloud)
          expect(cloud).to receive(:create_vm).with(
            kind_of(String), 'old-stemcell-id', kind_of(Hash), network_settings, kind_of(Array), kind_of(Hash)
          ).and_return('new-vm-cid')

          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags, true)
        end

        context 'when cloud-config/azs are not used' do
          let(:instance_model) { Models::Instance.make(uuid: SecureRandom.uuid, index: 5, job: 'fake-job', deployment: deployment, availability_zone: '') }

          it 'uses any cloud config if availability zones are not used, even though requested' do
            expect(non_default_cloud_factory).to receive(:get_name_for_az).at_least(:once).and_return ''
            expect(non_default_cloud_factory).to receive(:get).with('').at_least(:once).and_return(cloud)

            expect(CloudFactory).to receive(:create_from_deployment).and_return(non_default_cloud_factory)
            expect(cloud).to receive(:create_vm).with(
              kind_of(String), 'stemcell-id', kind_of(Hash), network_settings, kind_of(Array), kind_of(Hash)
            ).and_return('new-vm-cid')

            subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags, true)
          end
        end
      end

      it 'should create a vm and associate it with an instance' do
        expect(cloud).to receive(:create_vm).with(
          kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, ['fake-disk-cid'], {'bosh' => {'group' => expected_group,
          'groups' => expected_groups
        }}
        ).and_return('new-vm-cid')

        expect(agent_client).to receive(:wait_until_ready)
        expect(instance).to receive(:update_instance_settings)
        expect(instance).to receive(:update_cloud_properties!)

        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to change {
          vm = Models::Vm.where(cid: 'new-vm-cid').first
          vm.nil? ? nil : Models::Instance[vm.instance_id]
        }
      end

      it 'should create vm for the instance plans' do
        expect(cloud).to receive(:create_vm).with(
          kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, [], {'bosh' => {'group' => expected_group,
          'groups' => expected_groups
        }}
        ).and_return('new-vm-cid')

        expect(agent_client).to receive(:wait_until_ready)
        expect(deployment_plan).to receive(:ip_provider).and_return(ip_provider)
        expect(disk_manager).to receive(:attach_disks_if_needed).ordered
        expect(instance).to receive(:update_instance_settings).ordered
        expect(instance).to receive(:update_cloud_properties!)

        expect {
          subject.create_for_instance_plans([instance_plan], deployment_plan.ip_provider, tags)
        }.to change {
          vm = Models::Vm.where(cid: 'new-vm-cid').first
          vm.nil? ? 0 : Models::Instance.where(id: vm.instance_id).count
        }.from(0).to(1)
      end

      it 'should create vm for the instance plans with arbitrary metadata' do
        expect(cloud).to receive(:create_vm).with(
          kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, [], {'bosh' => {'group' => expected_group,
          'groups' => expected_groups
        }}
        ).and_return('new-vm-cid')

        expect(agent_client).to receive(:wait_until_ready)
        expect(deployment_plan).to receive(:ip_provider).and_return(ip_provider)
        expect(instance).to receive(:update_instance_settings)
        expect(instance).to receive(:update_cloud_properties!)

        expect {
          subject.create_for_instance_plans([instance_plan], deployment_plan.ip_provider, tags)
        }.to change {
          vm = Models::Vm.where(cid: 'new-vm-cid').first
          vm.nil? ? 0 : Models::Instance.where(id: vm.instance_id).count
        }.from(0).to(1)
      end

      it 'should record events' do
        expect(cloud).to receive(:create_vm).with(
          kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings, ['fake-disk-cid'], {'bosh' => {'group' => expected_group, 'groups' => expected_groups}}
        ).and_return('new-vm-cid')
        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to change { Models::Event.count }.from(0).to(2)

        event_1 = Models::Event.first
        expect(event_1.user).to eq('user')
        expect(event_1.action).to eq('create')
        expect(event_1.object_type).to eq('vm')
        expect(event_1.object_name).to eq(nil)
        expect(event_1.task).to eq("#{task.id}")
        expect(event_1.deployment).to eq(instance_model.deployment.name)
        expect(event_1.instance).to eq(instance_model.name)

        event_2 = Models::Event.order(:id)[2]
        expect(event_2.parent_id).to eq(1)
        expect(event_2.user).to eq('user')
        expect(event_2.action).to eq('create')
        expect(event_2.object_type).to eq('vm')
        expect(event_2.object_name).to eq('new-vm-cid')
        expect(event_2.task).to eq("#{task.id}")
        expect(event_2.deployment).to eq(instance_model.deployment.name)
        expect(event_2.instance).to eq(instance_model.name)
      end

      it 'should record events about error' do
        expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))
        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to raise_error Bosh::Clouds::VMCreationFailed

        event_2 = Models::Event.order(:id)[2]
        expect(event_2.error).to eq('Bosh::Clouds::VMCreationFailed')
      end

      it 'deletes created VM from cloud on DB failure' do
        expect(cloud).to receive(:create_vm).and_return('vm-cid')
        expect(Bosh::Director::Models::Vm).to receive(:create).and_raise('Bad DB. Bad.')
        expect(vm_deleter).to receive(:delete_vm_by_cid).with('vm-cid')
        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to raise_error ('Bad DB. Bad.')
      end

      it 'flushes the ARP cache' do
        allow(cloud).to receive(:create_vm).with(
          kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings.merge(extra_ip), ['fake-disk-cid'], {'bosh' => {'group' => expected_group, 'groups' => expected_groups}}
        ).and_return('new-vm-cid')

        allow(instance_plan).to receive(:network_settings_hash).and_return(
          network_settings.merge(extra_ip)
        )

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        expect(agent_broadcaster).to have_received(:delete_arp_entries).with(instance_model.vm_cid, ['192.168.1.3'])
      end

      it 'does not flush the arp cache when arp_flush set to false' do
        Config.flush_arp = false

        allow(cloud).to receive(:create_vm).with(
          kind_of(String), 'stemcell-id', {'ram' => '2gb'}, network_settings.merge(extra_ip), ['fake-disk-cid'], {'bosh' => {'group' => expected_group, 'groups' => expected_groups}}
        ).and_return('new-vm-cid')

        allow(instance_plan).to receive(:network_settings_hash).and_return(
          network_settings.merge(extra_ip)
        )

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        expect(agent_broadcaster).not_to have_received(:delete_arp_entries).with(instance_model.vm_cid, ['192.168.1.3'])

      end

      it 'sets vm metadata' do
        expect(cloud).to receive(:create_vm).with(
          kind_of(String), 'stemcell-id', kind_of(Hash), network_settings, ['fake-disk-cid'], {'bosh' => {'group' => expected_group,
          'groups' => expected_groups
        }}
        ).and_return('new-vm-cid')

        Timecop.freeze do
          expect(cloud).to receive(:set_vm_metadata) do |vm_cid, metadata|
            expect(vm_cid).to eq('new-vm-cid')
            expect(metadata).to match({
              'deployment' => 'deployment_name',
              'created_at' => Time.new.getutc.strftime('%Y-%m-%dT%H:%M:%SZ'),
              'job' => 'fake-job',
              'instance_group' => 'fake-job',
              'index' => '5',
              'director' => 'fake-director-name',
              'id' => instance_model.uuid,
              'name' => "fake-job/#{instance_model.uuid}",
              'mytag' => 'foobar',
            })
          end

          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        end
      end

      it 'updates instance job templates with new IP' do
        allow(cloud).to receive(:create_vm)
        expect(JobRenderer).to receive(:render_job_instances_with_cache).with([instance_plan], template_blob_cache, dns_encoder, logger)
        expect(instance).to receive(:apply_initial_vm_state)

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
      end

      it 'should retry creating a VM if it is told it is a retryable error' do
        expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(true))
        expect(cloud).to receive(:create_vm).once.and_return('fake-vm-cid')

        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to change {
          vm = Models::Vm.where(cid: 'fake-vm-cid').first
          vm.nil? ? false : vm.active }.from(false).to(true)
      end

      it 'should not retry creating a VM if it is told it is not a retryable error' do
        expect(cloud).to receive(:create_vm).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to raise_error(Bosh::Clouds::VMCreationFailed)
      end

      context 'when instance already has associated active_vm' do
        let(:old_vm) { Models::Vm.make(instance: instance_model, cpi: 'cpi1') }

        before { instance_model.active_vm = old_vm }

        it 'should not override the active vm on the instance model' do
            expect(cloud).to receive(:create_vm).with(kind_of(String), 'stemcell-id',
              kind_of(Hash), network_settings, ['fake-disk-cid'],
              {'bosh' =>
                {
                  'group' => expected_group,
                  'groups' => expected_groups
                }
              }).and_return('new-vm-cid')

            subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)

            instance_model.refresh
            old_vm.refresh

            expect(instance_model.active_vm).to eq(old_vm)
        end
      end

      it 'should try exactly the configured number of times (max_vm_create_tries) when it is a retryable error' do
        Config.max_vm_create_tries = 3

        expect(cloud).to receive(:create_vm).exactly(3).times.and_raise(Bosh::Clouds::VMCreationFailed.new(true))

        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to raise_error(Bosh::Clouds::VMCreationFailed)
      end

      it 'should not destroy the VM if the Config.keep_unreachable_vms flag is true' do
        Config.keep_unreachable_vms = true
        expect(cloud).to receive(:create_vm).and_return('new-vm-cid')
        expect(cloud).to_not receive(:delete_vm)

        expect(instance).to receive(:update_instance_settings).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to raise_error(Bosh::Clouds::VMCreationFailed)
      end

      it 'should have deep copy of environment' do
        env_id = nil

        expect(cloud).to receive(:create_vm) do |*args|
          env_id = args[5].object_id
        end

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)

        expect(cloud).to receive(:create_vm) do |*args|
          expect(args[5].object_id).not_to eq(env_id)
        end

        subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
      end

      it 'should destroy the VM if the Config.keep_unreachable_vms flag is false' do
        Config.keep_unreachable_vms = false

        expect(cloud).to receive(:create_vm).and_return('new-vm-cid')
        expect(cloud).to receive(:delete_vm)

        expect(instance).to receive(:update_instance_settings).once.and_raise(Bosh::Clouds::VMCreationFailed.new(false))

        expect {
          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        }.to raise_error(Bosh::Clouds::VMCreationFailed)
      end

      context 'nats information' do
        context 'is provided' do
          it 'should NOT include the uri in ENV' do
            Config.nats_uri = 'nats://localhost:1234'

            expect(cloud).to receive(:create_vm).with(
              kind_of(String), 'stemcell-id',
              kind_of(Hash), network_settings, ['fake-disk-cid'],
              {
                'bosh' => {
                  'group' => kind_of(String),
                  'groups' => kind_of(Array),
                }
              }
            ).and_return('new-vm-cid')
            subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
          end

          context 'when ca is included' do
            let(:cert_generator) {instance_double 'Bosh::Director::NatsClientCertGenerator'}
            let(:cert) {instance_double 'OpenSSL::X509::Certificate'}
            let(:private_key) {instance_double 'OpenSSL::PKey::RSA'}

            before do
              director_config = SpecHelper.spec_get_director_config
              allow(Config).to receive(:nats_client_ca_certificate_path).and_return(director_config['nats']['client_ca_certificate_path'])
              allow(Config).to receive(:nats_client_ca_private_key_path).and_return(director_config['nats']['client_ca_private_key_path'])
            end

            it 'should generate cert with agent ID in ENV' do
              allow(private_key).to receive(:to_pem).and_return('pkey begin\npkey content\npkey end\n')
              allow(cert).to receive(:to_pem).and_return('certificate begin\ncertificate content\ncertificate end\n')
              allow(NatsClientCertGenerator).to receive(:new).and_return(cert_generator)
              expect(cert_generator).to receive(:generate_nats_client_certificate).with(/^([0-9a-f\-]*)\.agent\.bosh-internal/).and_return({
                :cert => cert,
                :key => private_key
              })
              allow(Config).to receive(:nats_server_ca).and_return('nats begin\nnats content\nnats end\n')

              expect(cloud).to receive(:create_vm).with(
                kind_of(String), 'stemcell-id',
                kind_of(Hash), network_settings, ['fake-disk-cid'],
                {
                  'bosh' => {
                    'mbus' => {
                      'cert' => {
                        'ca' => 'nats begin\nnats content\nnats end\n',
                        'certificate' => 'certificate begin\ncertificate content\ncertificate end\n',
                        'private_key' => 'pkey begin\npkey content\npkey end\n',
                      }
                    },
                    'group' => kind_of(String),
                    'groups' => kind_of(Array),
                  }
                }
              ).and_return('new-vm-cid')
              subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
            end
          end
        end
        context 'is NOT provided' do
          it 'should not have the mbus key in ENV' do
            Config.nats_server_ca = nil
            Config.nats_uri = nil

            expect(cloud).to receive(:create_vm).with(
              kind_of(String), 'stemcell-id',
              kind_of(Hash), network_settings, ['fake-disk-cid'],
              {
                'bosh' => {
                  'group' => kind_of(String),
                  'groups' => kind_of(Array),
                }
              }
            ).and_return('new-vm-cid')
            subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
          end
        end
      end

      context 'Config.generate_vm_passwords flag is true' do
        before {
          Config.generate_vm_passwords = true
        }

        context 'no password is specified' do
          it 'should generate a random VM password' do
            expect(cloud).to receive(:create_vm) do |_, _, _, _, _, env|
              expect(env['bosh']['password'].length).to_not eq(0)
            end.and_return('new-vm-cid')

            subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
          end
        end

        context 'password is specified' do
          let(:env) do
            DeploymentPlan::Env.new(
              {'bosh' => {'password' => 'custom-password'}}
            )
          end
          it 'should generate a random VM password' do
            expect(cloud).to receive(:create_vm) do |_, _, _, _, _, env|
              expect(env['bosh']['password']).to eq('custom-password')
            end.and_return('new-vm-cid')

            subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
          end
        end
      end

      context 'Config.generate_vm_passwords flag is false' do
        before {
          Config.generate_vm_passwords = false
        }

        context 'no password is specified' do
          it 'should generate a random VM password' do
            expect(cloud).to receive(:create_vm) do |_, _, _, _, _, env|
              expect(env['bosh']).to eq({'group' => expected_group, 'groups' => expected_groups})
            end.and_return('new-vm-cid')

            subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
          end
        end

        context 'password is specified' do
          let(:env) do
            DeploymentPlan::Env.new(
              {'bosh' => {'password' => 'custom-password'}}
            )
          end
          it 'should generate a random VM password' do
            expect(cloud).to receive(:create_vm) do |_, _, _, _, _, env|
              expect(env['bosh']['password']).to eq('custom-password')
            end.and_return('new-vm-cid')

            subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
          end
        end
      end

      context 'cloud_properties, networks_settings, env interpolation' do
        let(:client_factory) { double(Bosh::Director::ConfigServer::ClientFactory) }
        let(:config_server_client) { double(Bosh::Director::ConfigServer::ConfigServerClient) }

        let(:instance_spec) { instance_double('Bosh::Director::DeploymentPlan::InstanceSpec') }

        let(:cloud_properties) do
          {
            'a' => 'bar',
            'b' => '((smurf_placeholder))',
            'c' => '((gargamel_placeholder))'
          }
        end

        let(:resolved_cloud_properties) do
          {
            'a' => 'bar',
            'b' => 'blue',
            'c' => 'green'
          }
        end

        let(:network_cloud_properties) do
          {'network-v1' => '((find-me))'}
        end

        let(:resolved_network_cloud_properties) do
          {'network-v1' => 'resolved-name'}
        end

        let(:unresolved_networks_settings) do
          {
            'name' => {
              'type' => 'dynamic',
              'cloud_properties' => network_cloud_properties,
              'dns' => 'dns',
              'default' => ['gateway']
            }
          }
        end

        let(:resolved_networks_settings) do
          {
            'name' => {
              'type' => 'dynamic',
              'cloud_properties' => resolved_network_cloud_properties,
              'dns' => 'dns',
              'default' => ['gateway']
            }
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
            }
          }
        end

        let(:env) do
          DeploymentPlan::Env.new(
            user_provided_env_hash
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
              'c' => '34'
            }
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
              }
            }
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
                'value_5_key' => 'value_5_value'
              },
              'value_6_key' => {
                'value_7_key' => 'value_7_value',
                'value_8_key' => 'value_8_value',
              },
              'a' => '12',
              'b' => {
                'c' => '34'
              },
              'group' => 'fake-director-name-deployment-name-fake-job',
              'groups' => ['fake-director-name', 'deployment-name', 'fake-job', 'fake-director-name-deployment-name', 'deployment-name-fake-job', 'fake-director-name-deployment-name-fake-job']
            }
          }
        end

        let(:desired_variable_set) { instance_double(Bosh::Director::Models::VariableSet) }

        before do
          allow(instance_spec).to receive(:as_apply_spec).and_return({})
          allow(instance_spec).to receive(:full_spec).and_return({})
          allow(instance_spec).to receive(:as_template_spec).and_return({})
          allow(instance_plan).to receive(:spec).and_return(instance_spec)
          allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).and_return(client_factory)
          allow(client_factory).to receive(:create_client).and_return(config_server_client)
          allow(Config).to receive(:agent_env).and_return(agent_env_bosh_hash)
        end

        it 'should interpolate them correctly, and merge agent env properties with the user provided ones' do
          instance_plan.instance.desired_variable_set = desired_variable_set

          expect(config_server_client).to receive(:interpolate_with_versioning).with(user_provided_env_hash, desired_variable_set).and_return(resolved_user_provided_env_hash)
          expect(config_server_client).to receive(:interpolate_with_versioning).with(cloud_properties, desired_variable_set).and_return(resolved_cloud_properties)
          expect(config_server_client).to receive(:interpolate_with_versioning).with(unresolved_networks_settings, desired_variable_set).and_return(resolved_networks_settings)

          expect(cloud).to receive(:create_vm) do |_, _, cloud_properties_param, network_settings_param, _, env_param|
            expect(cloud_properties_param).to eq(resolved_cloud_properties)
            expect(network_settings_param).to eq(resolved_networks_settings)
            expect(env_param).to eq(expected_env)
          end.and_return('new-vm-cid')

          subject.create_for_instance_plan(instance_plan, ['fake-disk-cid'], tags)
        end
      end
    end
  end
end
