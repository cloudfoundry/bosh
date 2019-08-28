require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe InstanceGroupSpecParser do
      subject(:parser) { described_class.new(deployment_plan, instance_group_spec, event_log, logger) }
      let(:template) do
        Models::Template.make(name: 'job-name')
      end
      let(:release) do
        Models::Release.make(name: 'fake-release').tap do |mock|
          allow(mock).to receive(:templates).and_return [template]
        end
      end
      let(:fake_releases) { { 'fake-release' => release } }
      let(:deployment_plan) do
        instance_double(
          Planner,
          model: deployment_model,
          update: UpdateConfig.new(
            'canaries' => 2,
            'max_in_flight' => 4,
            'canary_watch_time' => 60_000,
            'update_watch_time' => 30_000,
            'serial' => true,
          ),
          name: 'fake-deployment',
          networks: [network],
          releases: fake_releases,
          use_tmpfs_config: nil,
        )
      end
      let(:deployment_model) { Models::Deployment.make }
      let(:network) { ManualNetwork.new('fake-network-name', [], logger) }
      let(:task) { Models::Task.make(id: 42) }
      let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
      let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }

      let(:disk_collection) { PersistentDiskCollection.new(logger) }

      let(:links_parser) do
        instance_double(Bosh::Director::Links::LinksParser).tap do |mock|
          allow(mock).to receive(:parse_consumers_from_job)
          allow(mock).to receive(:parse_providers_from_job)
          allow(mock).to receive(:parse_provider_from_disk)
        end
      end

      before do
        allow(Bosh::Director::Links::LinksParser).to receive(:new).and_return(links_parser)
      end

      describe '#parse' do
        before do
          allow(deployment_plan).to receive(:vm_type).with(nil).and_return(nil)
          allow(deployment_plan).to receive(:vm_type).with('fake-vm-type').and_return(
            VmType.new(
              'name' => 'fake-vm-type',
              'cloud_properties' => {},
            ),
          )
          allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(
            Stemcell.parse(
              'alias' => 'fake-stemcell',
              'os' => 'fake-os',
              'version' => 1,
            ),
          )
          allow(deployment_plan).to receive(:disk_type).and_return(disk_type)
          allow(deployment_plan).to receive(:release).and_return(job_rel_ver)
          allow(PersistentDiskCollection).to receive(:new).and_return(disk_collection)

          allow(Api::ReleaseManager).to receive(:new).and_return fake_manager
        end

        let(:parse_options) do
          { 'is_deploy_action' => true }
        end
        let(:parsed_instance_group) { parser.parse(parse_options) }
        let(:disk_type) { instance_double(DiskType) }
        let(:fake_manager) do
          instance_double(Api::ReleaseManager).tap do |mock|
            allow(mock).to receive(:find_version).and_return(release)
            allow(mock).to receive(:find_by_name).and_return(release)
          end
        end
        let(:fake_job) do
          instance_double(
            DeploymentPlan::Job,
            add_properties: nil,
            name: 'job-name',
          )
        end
        let(:job_rel_ver) do
          instance_double(
            ReleaseVersion,
            template: { name: 'job-name' },
            name: 'fake-release',
            version: '1',
            get_or_create_template: fake_job,
          )
        end

        let(:instance_group_spec) do
          {
            'name' => 'instance-group-name',
            'jobs' => [
              {
                'name' => 'job-name',
                'release' => 'fake-release',
              },
            ],
            'vm_type' => 'fake-vm-type',
            'stemcell' => 'fake-stemcell',
            'env' => { 'key' => 'value' },
            'instances' => 1,
            'networks' => [{ 'name' => 'fake-network-name' }],
          }
        end

        it 'sets deployment name to instance group' do
          instance_group = parsed_instance_group
          expect(instance_group.deployment_name).to eq('fake-deployment')
        end

        describe 'name key' do
          it 'parses name' do
            instance_group = parsed_instance_group
            expect(instance_group.name).to eq('instance-group-name')
            expect(instance_group.canonical_name).to eq('instance-group-name')
          end
        end

        describe 'lifecycle key' do
          InstanceGroup::VALID_LIFECYCLE_PROFILES.each do |profile|
            it "is able to parse '#{profile}' as lifecycle profile" do
              instance_group_spec['lifecycle'] = profile
              instance_group = parsed_instance_group
              expect(instance_group.lifecycle).to eq(profile)
            end
          end

          it "defaults lifecycle profile to 'service'" do
            instance_group_spec.delete('lifecycle')
            instance_group = parsed_instance_group
            expect(instance_group.lifecycle).to eq('service')
          end

          it 'raises an error if lifecycle profile value is not known' do
            instance_group_spec['lifecycle'] = 'unknown'

            expect do
              parsed_instance_group
            end.to raise_error(
              JobInvalidLifecycle,
              "Invalid lifecycle 'unknown' for 'instance-group-name', valid lifecycle profiles are: service, errand",
            )
          end
        end

        describe 'jobs key' do
          context 'when value is an array of hashes' do
            context 'when a job does not specify a release' do
              before do
                instance_group_spec['jobs'] = [{
                  'name' => 'job-name',
                  'consumes' => { 'a' => { 'from' => 'link_name' } },
                }]
              end

              it 'should error' do
                expect do
                  parsed_instance_group
                end.to raise_error(
                  ValidationMissingField,
                  /Required property 'release' was not specified in object/,
                )
              end
            end

            context 'when one of the hashes specifies a release not specified in a deployment' do
              before do
                instance_group_spec['jobs'] = [{
                  'name' => 'job-name',
                  'release' => 'fake-release',
                }]
              end

              it 'raises an error because all referenced releases need to be specified under releases' do
                instance_group_spec['name'] = 'instance-group-name'

                expect(deployment_plan).to receive(:release)
                  .with('fake-release')
                  .and_return(nil)

                expect do
                  parsed_instance_group
                end.to raise_error(
                  InstanceGroupUnknownRelease,
                  "Job 'job-name' (instance group 'instance-group-name') references an unknown release 'fake-release'",
                )
              end
            end

            context 'when multiple hashes have the same name' do
              before do
                instance_group_spec['jobs'] << { 'name' => 'job-name', 'release' => 'fake-release' }
              end

              it 'raises an error because job dirs on a VM will become ambiguous' do
                instance_group_spec['name'] = 'fake-instance-group-name'
                expect do
                  parsed_instance_group
                end.to raise_error(
                  InstanceGroupInvalidJobs,
                  "Colocated job 'job-name' is already added to the instance group 'fake-instance-group-name'",
                )
              end
            end

            context 'when multiple hashes reference different releases' do
              let(:release_model_1) { Models::Release.make(name: 'release1') }
              let(:release_model_2) { Models::Release.make(name: 'release2') }
              let(:fake_manager) do
                instance_double(Api::ReleaseManager).tap do |mock|
                  allow(mock).to receive(:find_version).and_return(release_model_1, release_model_2)
                  allow(mock).to receive(:find_by_name).and_return(release_model_1, release_model_2)
                end
              end

              before do
                release_version_model_1 = Models::ReleaseVersion.make(version: '1', release: release_model_1)
                release_version_model_1.add_template(Models::Template.make(name: 'job-name1', release: release_model_1))

                release_version_model_2 = Models::ReleaseVersion.make(version: '1', release: release_model_2)
                release_version_model_2.add_template(Models::Template.make(name: 'job-name2', release: release_model_2))
                allow(deployment_plan).to receive(:releases).and_return(
                  [
                    { 'release1' => release_model_1 },
                    { 'release2' => release_model_2 },
                  ],
                )

                instance_group_spec['jobs'] = [
                  { 'name' => 'job-name1', 'release' => 'release1' },
                  { 'name' => 'job-name2', 'release' => 'release2' },
                ]
              end

              it 'uses the correct release for each job' do
                instance_group_spec['name'] = 'instance-group-name'

                rel_ver1 = instance_double(ReleaseVersion, name: 'release1', version: '1')
                job1 = make_job('job1', rel_ver1)
                allow(job1).to receive(:add_properties)
                allow(deployment_plan).to receive(:release)
                  .with('release1')
                  .and_return(rel_ver1)

                expect(rel_ver1).to receive(:get_or_create_template)
                  .with('job-name1')
                  .and_return(job1)

                rel_ver2 = instance_double(ReleaseVersion, name: 'release2', version: '1')
                job2 = make_job('job2', rel_ver2)
                allow(job2).to receive(:add_properties)
                allow(deployment_plan).to receive(:release)
                  .with('release2')
                  .and_return(rel_ver2)

                expect(rel_ver2).to receive(:get_or_create_template)
                  .with('job-name2')
                  .and_return(job2)

                parsed_instance_group
              end
            end

            context 'when one of the hashes is missing a name' do
              it 'raises an error because that is how jobs will be found' do
                instance_group_spec['jobs'] = [{}]
                expect do
                  parsed_instance_group
                end.to raise_error(
                  ValidationMissingField,
                  "Required property 'name' was not specified in object ({})",
                )
              end
            end

            context 'when one of the elements is not a hash' do
              it 'raises an error' do
                instance_group_spec['jobs'] = ['not-a-hash']
                expect do
                  parsed_instance_group
                end.to raise_error(
                  ValidationInvalidType,
                  %{Object ("not-a-hash") did not match the required type 'Hash'},
                )
              end
            end

            context 'when properties are provided in the job hash' do
              let(:job_rel_ver) do
                instance_double(
                  ReleaseVersion,
                  name: 'fake-release',
                  version: '1',
                  template: nil,
                )
              end

              before do
                instance_group_spec['jobs'] = [
                  {
                    'name' => 'job-name',
                    'properties' => {
                      'property_1' => 'property_1_value',
                      'property_2' => {
                        'life' => 'life_value',
                      },
                    },
                    'release' => 'fake-release',
                  },
                ]

                release_model = Models::Release.make(name: 'fake-release1')
                release_version_model = Models::ReleaseVersion.make(version: '1', release: release_model)
                release_version_model.add_template(Models::Template.make(name: 'job-name', release: release_model))
              end

              it 'assigns those properties to the intended job' do
                allow(deployment_plan).to receive(:release)
                  .with('fake-release')
                  .and_return(job_rel_ver)

                job = make_job('job-name', nil)
                allow(job_rel_ver).to receive(:get_or_create_template)
                  .with('job-name')
                  .and_return(job)
                expect(job).to receive(:add_properties)
                  .with({ 'property_1' => 'property_1_value', 'property_2' => { 'life' => 'life_value' } }, 'instance-group-name')

                parsed_instance_group
              end
            end

            context 'link parsing' do
              let(:rel_ver) { instance_double(ReleaseVersion, name: 'fake-release', version: '1') }
              let(:job) { make_job('job-name', nil) }

              before do
                instance_group_spec['jobs'] = [
                  {
                    'name' => 'job-name',
                    'release' => 'fake-release',
                  },
                ]
                release_model = Models::Release.make(name: 'fake-release-2')
                version = Models::ReleaseVersion.make(version: '1', release: release_model)
                version.add_template(
                  Models::Template.make(
                    name: 'job-name',
                    release: release_model,
                    spec: {},
                  ),
                )
                release_model.add_version(version)

                deployment_model = Models::Deployment.make(name: 'deployment')
                version.add_deployment(deployment_model)

                allow(deployment_plan).to receive(:release)
                  .with('fake-release')
                  .and_return(rel_ver)

                allow(rel_ver).to receive(:get_or_create_template)
                  .with('job-name')
                  .and_return(job)
                allow(job).to receive(:add_properties)
              end

              it 'should parse providers with LinksParser' do
                expect(links_parser).to receive(:parse_providers_from_job)
                parsed_instance_group
              end

              it 'should parse consumers with LinksParser' do
                expect(links_parser).to receive(:parse_consumers_from_job)
                parsed_instance_group
              end

              context 'when it is not a deploy action' do
                let(:parse_options) do
                  { 'is_deploy_action' => false }
                end

                it 'should skip parsing providers with LinksParser' do
                  expect(links_parser).to_not receive(:parse_providers_from_job)
                  parsed_instance_group
                end

                it 'should skip parsing consumers with LinksParser' do
                  expect(links_parser).to_not receive(:parse_consumers_from_job)
                  parsed_instance_group
                end
              end
            end
          end

          context 'when value is not an array' do
            it 'raises an error' do
              instance_group_spec['jobs'] = 'not-an-array'
              expect do
                parsed_instance_group
              end.to raise_error(
                ValidationInvalidType,
                %{Property 'jobs' value ("not-an-array") did not match the required type 'Array'},
              )
            end
          end
        end

        describe 'validating jobs in instance groups' do
          context 'when the templates key is specified' do
            before do
              instance_group_spec['templates'] = []
            end

            it 'raises a deprecation error' do
              expect { parsed_instance_group }.to raise_error(
                V1DeprecatedTemplate,
                "Instance group 'instance-group-name' specifies template or templates. This is no longer supported, please use jobs instead",
              )
            end
          end

          context 'when the template key is specified' do
            before do
              instance_group_spec['template'] = []
            end

            it 'raises a deprecation error' do
              expect { parsed_instance_group }.to raise_error(
                V1DeprecatedTemplate,
                "Instance group 'instance-group-name' specifies template or templates. This is no longer supported, "\
                'please use jobs instead',
              )
            end
          end

          context 'when no job key is specified' do
            before do
              instance_group_spec.delete(Job)
              instance_group_spec.delete('jobs')
            end

            it 'raises' do
              expect { parsed_instance_group }.to raise_error(
                ValidationMissingField,
                "Instance group 'instance-group-name' does not specify jobs key",
              )
            end
          end

          context 'when properties are listed at the top level' do
            before do
              instance_group_spec['properties'] = { 'deprecated' => 'property' }
            end

            it 'raises a deprecation error' do
              expect { parsed_instance_group }.to raise_error(
                V1DeprecatedInstanceGroupProperties,
                "Instance group 'instance-group-name' specifies 'properties' which is not supported. 'properties' are only "\
                "allowed in the 'jobs' array",
              )
            end
          end
        end

        describe 'persistent_disk key' do
          it 'parses persistent disk if present' do
            instance_group_spec['persistent_disk'] = 300

            expect(
              parsed_instance_group.persistent_disk_collection.generate_spec['persistent_disk'],
            ).to eq 300
          end

          it 'does not add a persistent disk if the size is 0' do
            instance_group_spec['persistent_disk'] = 0

            expect(
              parsed_instance_group.persistent_disk_collection.collection,
            ).to be_empty
          end

          it 'allows persistent disk to be nil' do
            instance_group_spec.delete('persistent_disk')

            expect(
              parsed_instance_group.persistent_disk_collection.generate_spec['persistent_disk'],
            ).to eq 0
          end

          it 'raises an error if the disk size is less than zero' do
            instance_group_spec['persistent_disk'] = -300
            expect do
              parsed_instance_group
            end.to raise_error(
              InstanceGroupInvalidPersistentDisk,
              "Instance group 'instance-group-name' references an invalid persistent disk size '-300'",
            )
          end
        end

        describe 'persistent_disk_type key' do
          it 'parses persistent_disk_type' do
            instance_group_spec['persistent_disk_type'] = 'fake-disk-type-name'
            expect(deployment_plan).to receive(:disk_type)
              .with('fake-disk-type-name')
              .and_return(disk_type)

            expect(disk_collection).to receive(:add_by_disk_type).with(disk_type)

            parsed_instance_group
          end

          it 'complains about unknown disk type' do
            instance_group_spec['persistent_disk_type'] = 'unknown-disk-type'
            expect(deployment_plan).to receive(:disk_type)
              .with('unknown-disk-type')
              .and_return(nil)

            expect do
              parsed_instance_group
            end.to raise_error(
              InstanceGroupUnknownDiskType,
              "Instance group 'instance-group-name' references an unknown disk type 'unknown-disk-type'",
            )
          end
        end

        describe 'validating persistent_disk_pool key' do
          it 'raises a validation error when present' do
            instance_group_spec['persistent_disk_pool'] = 'fake-disk-pool-name'
            expect do
              parsed_instance_group
            end.to raise_error(
              V1DeprecatedDiskPools,
              '`persistent_disk_pool` is not supported as an `instance_groups` key. Please use `persistent_disk_type` instead.',
            )
          end
        end

        describe 'persistent_disks' do
          let(:disk_type_small) { instance_double(DiskType) }
          let(:disk_type_large) { instance_double(DiskType) }
          let(:disk_collection) { instance_double(PersistentDiskCollection) }

          context 'when persistent disks are well formatted' do
            before do
              instance_group_spec['persistent_disks'] = [
                { 'name' => 'my-disk', 'type' => 'disk-type-small' },
                { 'name' => 'my-favourite-disk', 'type' => 'disk-type-large' },
              ]
              expect(deployment_plan).to receive(:disk_type)
                .with('disk-type-small')
                .and_return(disk_type_small)
              expect(deployment_plan).to receive(:disk_type)
                .with('disk-type-large')
                .and_return(disk_type_large)
              expect(disk_collection).to receive(:add_by_disk_name_and_type)
                .with('my-favourite-disk', disk_type_large)
              expect(disk_collection).to receive(:add_by_disk_name_and_type)
                .with('my-disk', disk_type_small)
            end

            it 'should call LinksParser to create disk providers for each specified disk' do
              expect(links_parser).to receive(:parse_provider_from_disk).twice
              parsed_instance_group
            end
          end

          context 'when persistent disks are NOT well formatted' do
            it 'complains about empty names' do
              instance_group_spec['persistent_disks'] = [{ 'name' => '', 'type' => 'disk-type-small' }]
              expect do
                parsed_instance_group
              end.to raise_error(
                InstanceGroupInvalidPersistentDisk,
                "Instance group 'instance-group-name' persistent_disks's section contains a disk with no name",
              )
            end

            it 'complains about two disks with the same name' do
              instance_group_spec['persistent_disks'] = [
                { 'name' => 'same', 'type' => 'disk-type-small' },
                { 'name' => 'same', 'type' => 'disk-type-small' },
              ]

              expect do
                parsed_instance_group
              end.to raise_error(
                InstanceGroupInvalidPersistentDisk,
                "Instance group 'instance-group-name' persistent_disks's section contains duplicate names",
              )
            end

            it 'complains about unknown disk type' do
              instance_group_spec['persistent_disks'] = [
                { 'name' => 'disk-name-0', 'type' => 'disk-type-small' },
              ]
              expect(deployment_plan).to receive(:disk_type)
                .with('disk-type-small')
                .and_return(nil)

              expect do
                parsed_instance_group
              end.to raise_error(
                InstanceGroupUnknownDiskType,
                "Instance group 'instance-group-name' persistent_disks's section references an unknown disk type 'disk-type-small'",
              )
            end
          end
        end

        context 'when job has multiple persistent_disks keys' do
          it 'raises an error if persistent_disk and persistent_disk_type are both present' do
            instance_group_spec['persistent_disk'] = 300
            instance_group_spec['persistent_disk_type'] = 'fake-disk-pool-name'

            expect do
              parsed_instance_group
            end.to raise_error(
              InstanceGroupInvalidPersistentDisk,
              "Instance group 'instance-group-name' specifies more than one of the following keys: " \
              "'persistent_disk', 'persistent_disk_type', and 'persistent_disks'. Choose one.",
            )
          end
        end

        describe 'validating vm types and vm resources' do
          let(:instance_group_spec) do
            {
              'name' => 'instance-group-name',
              'jobs' => [],
              'release' => 'fake-release-name',
              'stemcell' => 'fake-stemcell',
              'env' => { 'key' => 'value' },
              'instances' => 1,
              'networks' => [{ 'name' => 'fake-network-name' }],
            }
          end

          context 'when more than one vm config is given' do
            let(:vm_resources) do
              {
                'vm_resources' => {
                  'cpu' => 4,
                  'ram' => 2048,
                  'ephemeral_disk_size' => 100,
                },
              }
            end

            let(:vm_type) { { 'vm_type' => 'fake-vm-type' } }

            it 'raises an error for vm_type, vm_resources' do
              instance_group_spec.merge!(vm_type).merge!(vm_resources)

              expect do
                parsed_instance_group
              end.to raise_error(InstanceGroupBadVmConfiguration,
                                 "Instance group 'instance-group-name' can only specify 'vm_type' or 'vm_resources' keys.")
            end
          end

          context 'when the resource_pool key is given' do
            let(:resource_pool) { { 'resource_pool' => 'fake-resource-pool-name' } }

            it 'raises a deprecation error' do
              instance_group_spec.merge!(resource_pool)
              expect do
                parsed_instance_group
              end.to raise_error(V1DeprecatedResourcePool,
                                 "Instance groups no longer support resource_pool, please use 'vm_type' or 'vm_resources' keys")
            end
          end

          context 'when neither vm type nor vm resources are given' do
            it 'raises an error' do
              expect do
                parsed_instance_group
              end.to raise_error(InstanceGroupBadVmConfiguration,
                                 "Instance group 'instance-group-name' is missing either 'vm_type' or 'vm_resources' section.")
            end
          end
        end

        describe 'vm type and stemcell key' do
          before do
            allow(deployment_plan).to receive(:vm_type).with('fake-vm-type').and_return(
              VmType.new(
                'name' => 'fake-vm-type',
                'cloud_properties' => {},
              ),
            )
            allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(
              Stemcell.parse(
                'alias' => 'fake-stemcell',
                'os' => 'fake-os',
                'version' => 1,
              ),
            )
          end

          it 'parses vm type and stemcell' do
            instance_group = parsed_instance_group
            expect(instance_group.vm_type.name).to eq('fake-vm-type')
            expect(instance_group.vm_type.cloud_properties).to eq({})
            expect(instance_group.stemcell.alias).to eq('fake-stemcell')
            expect(instance_group.stemcell.version).to eq('1')
            expect(instance_group.env.spec).to eq('key' => 'value')
          end

          context 'vm type cannot be found' do
            before do
              allow(deployment_plan).to receive(:vm_type).with('fake-vm-type').and_return(nil)
            end

            it 'errors out' do
              expect { parsed_instance_group }.to raise_error(
                InstanceGroupUnknownVmType,
                "Instance group 'instance-group-name' references an unknown vm type 'fake-vm-type'",
              )
            end
          end

          context 'stemcell cannot be found' do
            before do
              allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(nil)
            end

            it 'errors out' do
              expect { parsed_instance_group }.to raise_error(
                InstanceGroupUnknownStemcell,
                "Instance group 'instance-group-name' references an unknown stemcell 'fake-stemcell'",
              )
            end
          end
        end

        describe 'vm resources' do
          let(:instance_group_spec) do
            {
              'name' => 'instance-group-name',
              'jobs' => [],
              'release' => 'fake-release-name',
              'stemcell' => 'fake-stemcell',
              'env' => { 'key' => 'value' },
              'instances' => 1,
              'networks' => [{ 'name' => 'fake-network-name' }],
              'vm_resources' => {
                'cpu' => 4,
                'ram' => 2048,
                'ephemeral_disk_size' => 100,
              },
            }
          end

          before do
            allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(
              Stemcell.parse(
                'alias' => 'fake-stemcell',
                'os' => 'fake-os',
                'version' => 1,
              ),
            )
          end

          context 'when vm_resources are given' do
            it 'parses the vm resources' do
              instance_group = nil
              expect do
                instance_group = parsed_instance_group
              end.to_not raise_error
              expect(instance_group.vm_resources.cpu).to eq(4)
              expect(instance_group.vm_resources.ram).to eq(2048)
              expect(instance_group.vm_resources.ephemeral_disk_size).to eq(100)
            end
          end
        end

        describe 'vm_extensions key' do
          let(:vm_extension_1) do
            {
              'name' => 'vm_extension_1',
              'cloud_properties' => { 'property' => 'value' },
            }
          end

          let(:vm_extension_2) do
            {
              'name' => 'vm_extension_2',
              'cloud_properties' => { 'another_property' => 'value1', 'property' => 'value2' },
            }
          end

          before do
            allow(deployment_plan).to receive(:vm_type).with('fake-vm-type').and_return(
              VmType.new(
                'name' => 'fake-vm-type',
                'cloud_properties' => {},
              ),
            )
            allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(
              Stemcell.parse(
                'alias' => 'fake-stemcell',
                'os' => 'fake-os',
                'version' => 1,
              ),
            )
            allow(deployment_plan).to receive(:vm_extension).with('vm_extension_1').and_return(
              VmExtension.new(vm_extension_1),
            )
            allow(deployment_plan).to receive(:vm_extension).with('vm_extension_2').and_return(
              VmExtension.new(vm_extension_2),
            )
          end

          context 'job has one vm_extension' do
            it 'parses the vm_extension' do
              instance_group_spec['vm_extensions'] = ['vm_extension_1']

              instance_group = parsed_instance_group
              expect(instance_group.vm_extensions.size).to eq(1)
              expect(instance_group.vm_extensions.first.name).to eq('vm_extension_1')
              expect(instance_group.vm_extensions.first.cloud_properties).to eq('property' => 'value')
            end
          end
        end

        describe 'instances key' do
          it 'parses out desired instances' do
            instance_group = parsed_instance_group

            expected_instances = [
              DesiredInstance.new(instance_group, deployment_plan),
            ]
            expect(instance_group.desired_instances).to eq(expected_instances)
          end
        end

        describe 'networks key' do
          before { instance_group_spec['networks'].first['static_ips'] = '10.0.0.2 - 10.0.0.4' } # 2,3,4

          context 'when the number of static ips is less than number of instances' do
            it 'raises an exception because if a job uses static ips all instances must have a static ip' do
              instance_group_spec['instances'] = 4
              expect do
                parsed_instance_group
              end.to raise_error(
                InstanceGroupNetworkInstanceIpMismatch,
                "Instance group 'instance-group-name' has 4 instances but was allocated 3 static IPs "\
                "in network 'fake-network-name'",
              )
            end
          end

          context 'when the number of static ips is greater the number of instances' do
            it 'raises an exception because the extra ip is wasted' do
              instance_group_spec['instances'] = 2
              expect do
                parsed_instance_group
              end.to raise_error(
                InstanceGroupNetworkInstanceIpMismatch,
                "Instance group 'instance-group-name' has 2 instances but was allocated 3 static IPs in "\
                "network 'fake-network-name'",
              )
            end
          end

          context 'when number of static ips matches the number of instances' do
            it 'does not raise an exception' do
              instance_group_spec['instances'] = 3
              expect { parsed_instance_group }.to_not raise_error
            end
          end

          context 'when there are multiple networks specified as default for a property' do
            it 'errors' do
              instance_group_spec['instances'] = 3
              instance_group_spec['networks'].first['default'] = %w[gateway dns]
              instance_group_spec['networks'] << instance_group_spec['networks'].first.merge('name' => 'duped-network') # dupe it
              duped_network = ManualNetwork.new('duped-network', [], logger)
              allow(deployment_plan).to receive(:networks).and_return([duped_network, network])

              expect do
                parsed_instance_group
              end.to raise_error(
                JobNetworkMultipleDefaults,
                "Instance group 'instance-group-name' specified more than one network to contain default. " \
                "'dns' has default networks: 'fake-network-name', 'duped-network'. " \
                "'gateway' has default networks: 'fake-network-name', 'duped-network'.",
              )
            end
          end

          context 'when there are no networks specified as default for a property' do
            context 'when there is only one network' do
              it 'picks the only network as default' do
                instance_group_spec['instances'] = 3
                allow(deployment_plan).to receive(:networks).and_return([network])
                instance_group = parsed_instance_group

                expect(instance_group.default_network['dns']).to eq('fake-network-name')
                expect(instance_group.default_network['gateway']).to eq('fake-network-name')
              end
            end

            context 'when there are two networks, each being a separate default' do
              let(:network2) { ManualNetwork.new('fake-network-name-2', [], logger) }

              it 'picks the only network as default' do
                instance_group_spec['networks'].first['default'] = ['dns']
                instance_group_spec['networks'] << { 'name' => 'fake-network-name-2', 'default' => ['gateway'] }
                instance_group_spec['instances'] = 3
                allow(deployment_plan).to receive(:networks).and_return([network, network2])
                instance_group = parsed_instance_group

                expect(instance_group.default_network['dns']).to eq('fake-network-name')
                expect(instance_group.default_network['gateway']).to eq('fake-network-name-2')
              end
            end
          end
        end

        describe 'azs key' do
          context 'when there is a key but empty values' do
            it 'raises an exception' do
              instance_group_spec['azs'] = []

              expect do
                parsed_instance_group
              end.to raise_error(
                JobMissingAvailabilityZones, "Instance group 'instance-group-name' has empty availability zones"
              )
            end
          end

          context 'when there is a key with values' do
            it 'parses each value into the AZ on the deployment' do
              zone1, zone2 = set_up_azs!(%w[zone1 zone2], instance_group_spec, deployment_plan)
              allow(network).to receive(:has_azs?).and_return(true)
              expect(parsed_instance_group.availability_zones).to eq([zone1, zone2])
            end

            it 'raises an exception if the value are not strings' do
              instance_group_spec['azs'] = ['valid_zone', 3]
              allow(network).to receive(:has_azs?).and_return(true)
              allow(deployment_plan).to receive(:availability_zone).with('valid_zone') { instance_double(AvailabilityZone) }

              expect do
                parsed_instance_group
              end.to raise_error(
                JobInvalidAvailabilityZone,
                "Instance group 'instance-group-name' has invalid availability zone '3', string expected",
              )
            end

            it 'raises an exception if the referenced AZ doesnt exist in the deployment' do
              instance_group_spec['azs'] = %w[existent_zone nonexistent_zone]
              allow(network).to receive(:has_azs?).and_return(true)
              allow(deployment_plan).to receive(:availability_zone).with('existent_zone') { instance_double(AvailabilityZone) }
              allow(deployment_plan).to receive(:availability_zone).with('nonexistent_zone') { nil }

              expect do
                parsed_instance_group
              end.to raise_error(
                JobUnknownAvailabilityZone, "Instance group 'instance-group-name' references unknown "\
                "availability zone 'nonexistent_zone'"
              )
            end

            it 'raises an error if the referenced AZ is not specified on networks' do
              allow(network).to receive(:has_azs?).and_return(false)

              expect do
                parsed_instance_group
              end.to raise_error(
                JobNetworkMissingRequiredAvailabilityZone,
                "Instance group 'instance-group-name' must specify availability zone that matches availability "\
                "zones of network 'fake-network-name'",
              )
            end

            describe 'validating AZs against the networks of the job' do
              it 'validates that every network satisfies job AZ requirements' do
                set_up_azs!(%w[zone1 zone2], instance_group_spec, deployment_plan)
                instance_group_spec['networks'] = [
                  { 'name' => 'first-network' },
                  { 'name' => 'second-network', 'default' => %w[dns gateway] },
                ]

                first_network = instance_double(
                  ManualNetwork,
                  name: 'first-network',
                  has_azs?: true,
                  validate_reference_from_job!: true,
                )
                second_network = instance_double(
                  ManualNetwork,
                  name: 'second-network',
                  has_azs?: true,
                  validate_reference_from_job!: true,
                )
                allow(deployment_plan).to receive(:networks).and_return([first_network, second_network])

                parsed_instance_group

                expect(first_network).to have_received(:has_azs?).with(%w[zone1 zone2])
                expect(second_network).to have_received(:has_azs?).with(%w[zone1 zone2])
              end
            end
          end

          context 'when there is a key with the wrong type' do
            it 'an exception is raised' do
              instance_group_spec['azs'] = 3

              expect do
                parsed_instance_group
              end.to raise_error(
                ValidationInvalidType, "Property 'azs' value (3) did not match the required type 'Array'"
              )
            end
          end
        end

        describe 'migrated_from' do
          let(:instance_group_spec) do
            {
              'name' => 'instance-group-name',
              'jobs' => [],
              'release' => 'fake-release-name',
              'vm_type' => 'fake-vm-type',
              'stemcell' => 'fake-stemcell',
              'instances' => 1,
              'networks' => [{ 'name' => 'fake-network-name' }],
              'migrated_from' => [{ 'name' => 'job-1', 'az' => 'z1' }, { 'name' => 'job-2', 'az' => 'z2' }],
              'azs' => %w[z1 z2],
            }
          end
          before do
            allow(deployment_plan).to receive(:vm_type).with('fake-vm-type').and_return(
              VmType.new(
                'name' => 'fake-vm-type',
                'cloud_properties' => {},
              ),
            )
            allow(deployment_plan).to receive(:stemcell).with('fake-stemcell').and_return(
              Stemcell.parse(
                'alias' => 'fake-stemcell',
                'os' => 'fake-os',
                'version' => 1,
              ),
            )
            allow(network).to receive(:has_azs?).and_return(true)
            allow(deployment_plan).to receive(:availability_zone).with('z1') { AvailabilityZone.new('z1', {}) }
            allow(deployment_plan).to receive(:availability_zone).with('z2') { AvailabilityZone.new('z2', {}) }
          end

          it 'sets migrated_from on a job' do
            instance_group = parsed_instance_group
            expect(instance_group.migrated_from[0].name).to eq('job-1')
            expect(instance_group.migrated_from[0].availability_zone).to eq('z1')
            expect(instance_group.migrated_from[1].name).to eq('job-2')
            expect(instance_group.migrated_from[1].availability_zone).to eq('z2')
          end

          context 'when az is specified' do
            context 'when migrated job refers to az that is not in the list of availaibility_zones key' do
              it 'raises an error' do
                instance_group_spec['migrated_from'] = [{ 'name' => 'job-1', 'az' => 'unknown_az' }]

                expect do
                  parsed_instance_group
                end.to raise_error(
                  DeploymentInvalidMigratedFromJob,
                  "Instance group 'job-1' specified for migration to instance group 'instance-group-name' refers to availability zone 'unknown_az'. " \
                  "Az 'unknown_az' is not in the list of availability zones of instance group 'instance-group-name'.",
                )
              end
            end
          end
        end

        describe 'remove_dev_tools' do
          before { allow(Config).to receive(:remove_dev_tools).and_return(false) }

          it 'does not add remove_dev_tools by default' do
            instance_group = parsed_instance_group
            expect(instance_group.env.spec['bosh']).to eq(nil)
          end

          it 'does what the job env says' do
            instance_group_spec['env'] = { 'bosh' => { 'remove_dev_tools' => 'custom' } }
            instance_group = parsed_instance_group
            expect(instance_group.env.spec['bosh']['remove_dev_tools']).to eq('custom')
          end

          describe 'when director manifest specifies director.remove_dev_tools' do
            before { allow(Config).to receive(:remove_dev_tools).and_return(true) }

            it 'should do what director wants' do
              instance_group = parsed_instance_group
              expect(instance_group.env.spec['bosh']['remove_dev_tools']).to eq(true)
            end
          end

          describe 'when both the job and director specify' do
            before do
              allow(Config).to receive(:remove_dev_tools).and_return(true)
              instance_group_spec['env'] = { 'bosh' => { 'remove_dev_tools' => false } }
            end

            it 'defers to the job' do
              instance_group = parsed_instance_group
              expect(instance_group.env.spec['bosh']['remove_dev_tools']).to eq(false)
            end
          end
        end

        describe 'update' do
          let(:update) do
            {}
          end

          before do
            instance_group_spec['update'] = update
          end

          it 'can be overridden by canaries option' do
            parse_options['canaries'] = 7

            expect(parsed_instance_group.update.canaries(nil)).to eq(7)
          end

          it 'can be overridden by max-in-flight option' do
            parse_options['max_in_flight'] = 8

            expect(parsed_instance_group.update.max_in_flight(nil)).to eq(8)
          end

          context 'when provided an instance_group_spec with a vm_strategy' do
            let(:update) do
              { 'vm_strategy' => 'create-swap-delete' }
            end

            it 'should set the instance_group strategy as create-swap-delete' do
              expect(parsed_instance_group.update.vm_strategy).to eq('create-swap-delete')
            end
          end
        end

        describe 'use_tmpfs_config' do
          before do
            allow(deployment_plan).to receive(:use_tmpfs_config).and_return(true)
          end

          it 'sets the appropriate tmpfs properties to true on the env' do
            instance_group = parsed_instance_group
            expect(instance_group.env.spec['bosh']['job_dir']['tmpfs']).to eq(true)
            expect(instance_group.env.spec['bosh']['agent']['settings']['tmpfs']).to eq(true)
          end

          context 'when use_tmpfs_config is explicitly disabled' do
            before do
              allow(deployment_plan).to receive(:use_tmpfs_config).and_return(false)
            end

            it 'sets the appropriate tmpfs properties to true on the env' do
              instance_group = parsed_instance_group
              expect(instance_group.env.spec['bosh']['job_dir']['tmpfs']).to eq(false)
              expect(instance_group.env.spec['bosh']['agent']['settings']['tmpfs']).to eq(false)
            end
          end

          context 'when use_tmpfs_config is not specified' do
            before do
              allow(deployment_plan).to receive(:use_tmpfs_config).and_return(nil)
            end

            it 'sets the appropriate tmpfs properties to true on the env' do
              instance_group = parsed_instance_group
              expect(instance_group.env.spec).to_not have_key('bosh')
            end
          end

          context 'when the env explicitly disables bosh.job_dir.tmpfs' do
            before do
              instance_group_spec['env'] = {
                'bosh' => {
                  'agent' => {
                    'settings' => {
                      'tmpfs' => false,
                    },
                  },
                  'job_dir' => {
                    'tmpfs' => false,
                  },
                },
              }
            end

            it 'sets the appropriate tmpfs properties to false on the env' do
              instance_group = parsed_instance_group
              expect(instance_group.env.spec['bosh']['job_dir']['tmpfs']).to eq(false)
              expect(instance_group.env.spec['bosh']['agent']['settings']['tmpfs']).to eq(false)
            end
          end
        end

        def set_up_azs!(azs, instance_group_spec, deployment_plan)
          instance_group_spec['azs'] = azs
          azs.map do |az_name|
            fake_az = instance_double(AvailabilityZone, name: az_name)
            allow(deployment_plan).to receive(:availability_zone).with(az_name) { fake_az }
            fake_az
          end
        end

        def make_job(name, rel_ver)
          instance_double(
            Job,
            name: name,
            release: rel_ver,
            link_infos: {},
          )
        end
      end
    end
  end
end
