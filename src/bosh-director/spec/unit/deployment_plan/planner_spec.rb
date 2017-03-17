require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Planner do
      subject(:planner) { described_class.new(planner_attributes, minimal_manifest, cloud_config, runtime_config, deployment_model, options) }

      let(:options) { {} }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }
      let(:cloud_config) { nil }
      let(:runtime_config) { nil }
      let(:manifest_text) { generate_manifest_text }
      let(:planner_attributes) { {name: 'mycloud', properties: {}} }
      let(:deployment_model) { Models::Deployment.make }

      def generate_manifest_text
        YAML.dump minimal_manifest
      end

      let(:minimal_manifest) do
        {
          'name' => 'minimal',

          'releases' => [{
            'name' => 'appcloud',
            'version' => '0.1' # It's our dummy valid release from spec/assets/valid_release.tgz
          }],

          'networks' => [{
            'name' => 'a',
            'subnets' => [],
          }],

          'compilation' => {
            'workers' => 1,
            'network' => 'a',
            'cloud_properties' => {},
          },

          'resource_pools' => [],

          'update' => {
            'canaries' => 2,
            'canary_watch_time' => 4000,
            'max_in_flight' => 1,
            'update_watch_time' => 20
          }
        }
      end

      describe 'with invalid options' do
        it 'raises an error if name are not given' do
          planner_attributes.delete(:name)

          expect {
            planner
          }.to raise_error KeyError
        end
      end

      its(:model) { deployment_model }

      describe 'with valid options' do
        let(:stemcell_model) { Bosh::Director::Models::Stemcell.create(name: 'default', version: '1', cid: 'abc') }
        let(:resource_pool_spec) do
          {
            'name' => 'default',
            'cloud_properties' => {},
            'network' => 'default',
            'stemcell' => {
              'name' => 'default',
              'version' => '1'
            }
          }
        end
        let(:resource_pools) { [ResourcePool.new(resource_pool_spec)] }
        let(:vm_type) { VmType.new({'name' => 'vm_type'}) }

        before do
          deployment_model.add_stemcell(stemcell_model)
          cloud_planner = CloudPlanner.new({
            networks: [Network.new('default', logger)],
            global_network_resolver: GlobalNetworkResolver.new(planner, [], logger),
            ip_provider_factory: IpProviderFactory.new(true, logger),
            disk_types: [],
            availability_zones_list: [],
            vm_type: vm_type,
            resource_pools: resource_pools,
            compilation: nil,
            logger: logger,
          })
          planner.cloud_planner = cloud_planner
          allow(Config).to receive(:dns_enabled?).and_return(false)
          allow(Config).to receive_message_chain(:current_job, :username).and_return('username')
          task = Models::Task.make(state: 'processing')
          allow(Config).to receive_message_chain(:current_job, :task_id).and_return(task.id)
        end

        it 'should parse recreate' do
          expect(planner.recreate).to eq(false)

          plan = described_class.new(planner_attributes, manifest_text, cloud_config, runtime_config, deployment_model, 'recreate' => true)
          expect(plan.recreate).to eq(true)
        end

        describe '#bind_models' do
          context 'if fix is set' do
            let(:options) do
              {'fix' => true}
            end

            it 'delegates to DeploymentPlan Assembler with correct options' do
              expected_options = {fix: true, tags: {}}
              expect_any_instance_of(DeploymentPlan::Assembler).to receive(:bind_models).with expected_options
              planner.bind_models
            end
          end

          context 'if tags are set' do
            let(:options) do
              {'tags' => {'key1' => 'value1'}}
            end

            it 'delegates to DeploymentPlan Assembler with correct options' do
              expected_options = {tags: {'key1' => 'value1'}, fix: false}
              expect_any_instance_of(DeploymentPlan::Assembler).to receive(:bind_models).with expected_options
              planner.bind_models
            end
          end
        end

        describe '#instance_groups_starting_on_deploy' do
          before { subject.add_instance_group(job1) }
          let(:job1) do
            instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
              name: 'fake-job1-name',
              canonical_name: 'fake-job1-cname',
              is_service?: true,
              is_errand?: false,
            })
          end

          before { subject.add_instance_group(job2) }
          let(:job2) do
            instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
              name: 'fake-job2-name',
              canonical_name: 'fake-job2-cname',
              lifecycle: 'errand',
              is_service?: false,
              is_errand?: true,
            })
          end

          context 'with errand running via keep-alive' do
            before do
              allow(job2).to receive(:instances).and_return([
                instance_double('Bosh::Director::DeploymentPlan::Instance', {
                  model: instance_double('Bosh::Director::Models::Instance', {
                    vm_cid: 'foo-1234',
                  })
                })
              ])
            end

            it 'returns both the regular job and keep-alive errand' do
              expect(subject.instance_groups_starting_on_deploy).to eq([job1, job2])
            end
          end

          context 'with errand not running' do
            before do
              allow(job2).to receive(:instances).and_return([
                instance_double('Bosh::Director::DeploymentPlan::Instance', {
                  model: instance_double('Bosh::Director::Models::Instance', {
                    vm_cid: nil,
                  })
                })
              ])
            end

            it 'returns only the regular job' do
              expect(subject.instance_groups_starting_on_deploy).to eq([job1])
            end
          end
        end

        describe '#errand_instance_groups' do
          let(:instance_group_1) do
            instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
              name: 'fake-instance-group-1-name',
              canonical_name: 'fake-instance-group-1-cname',
              is_service?: true,
              is_errand?: false,
            })
          end

          let(:instance_group_2) do
            instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
              name: 'fake-instance-group-2-name',
              canonical_name: 'fake-instance-group-2-cname',
              is_service?: false,
              is_errand?: true,
            })
          end

          let(:instance_group_3) do
            instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
              name: 'fake-instance-group-3-name',
              canonical_name: 'fake-instance-group-3-cname',
              is_service?: false,
              is_errand?: true,
            })
          end

          before do
            subject.add_instance_group(instance_group_1)
            subject.add_instance_group(instance_group_2)
            subject.add_instance_group(instance_group_3)
          end

          it 'return instance groups with errand lifecylce' do
            expect(subject.errand_instance_groups).to match_array([instance_group_2, instance_group_3])
          end
        end

        describe '#persist_updates!' do
          before do
            setup_global_config_and_stubbing
          end

          context 'given prior deployment with old release versions' do
            let(:stale_release_version) do
              release = Bosh::Director::Models::Release.create(name: 'stale')
              Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
            end
            let(:another_stale_release_version) do
              release = Bosh::Director::Models::Release.create(name: 'another_stale')
              Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
            end
            let(:same_release_version) do
              release = Bosh::Director::Models::Release.create(name: 'same')
              Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
            end
            let!(:new_release_version) do
              release = Bosh::Director::Models::Release.create(name: 'new')
              Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
            end

            before do
              deployment_model.add_release_version stale_release_version
              deployment_model.add_release_version another_stale_release_version
              deployment_model.add_release_version same_release_version

              planner.add_release(ReleaseVersion.new(deployment_model, {'name' => 'same', 'version' => '123'}))
              planner.add_release(ReleaseVersion.new(deployment_model, {'name' => 'new', 'version' => '123'}))
              planner.bind_models
            end

            it 'updates the release version on the deployment to be the ones from the provided manifest' do
              expect(deployment_model.release_versions).to include(stale_release_version)
              planner.persist_updates!
              expect(deployment_model.release_versions).to_not include(stale_release_version)
              expect(deployment_model.release_versions).to include(same_release_version)
              expect(deployment_model.release_versions).to include(new_release_version)
            end

            it 'locks the stale releases when removing them' do
              expect(subject).to receive(:with_release_locks).with(['stale', 'another_stale'])
              subject.persist_updates!
            end

            it 'de-dupes by release name when locking' do
              stale_release_version_124 = Bosh::Director::Models::ReleaseVersion.create(
                release: Bosh::Director::Models::Release.find(name: 'stale'),
                version: '124')
              deployment_model.add_release_version stale_release_version_124

              expect(subject).to receive(:with_release_locks).with(['stale', 'another_stale'])
              subject.persist_updates!
            end
          end

          it 'saves original manifest' do
            original_manifest = generate_manifest_text
            minimal_manifest['update']['canaries'] = 10
            planner.persist_updates!
            expect(deployment_model.manifest).to eq(original_manifest)
          end
        end

        describe '#update_stemcell_references!' do
          let(:stemcell_model_2) { Bosh::Director::Models::Stemcell.create(name: 'stem2', version: '1.0', cid: 'def') }

          before do
            setup_global_config_and_stubbing
            deployment_model.add_stemcell(stemcell_model_2)
          end

          context 'when using resource pools' do
            context "when the stemcells associated with the resource pools have diverged from the stemcells associated with the planner" do
              it 'it removes the given deployment from any stemcell it should not be associated with' do
                planner.bind_models

                expect(stemcell_model.deployments).to include(deployment_model)
                expect(stemcell_model_2.deployments).to include(deployment_model)

                planner.update_stemcell_references!

                expect(stemcell_model.reload.deployments).to include(deployment_model)
                expect(stemcell_model_2.reload.deployments).to_not include(deployment_model)
              end
            end
          end

          context 'when using vm types and stemcells' do
            let(:resource_pools) { [] }
            before do
              planner.add_stemcell(Stemcell.parse({
                'alias' => 'default',
                'name' => 'default',
                'version' => '1',
              }))
              planner.bind_models
            end
            context "when the stemcells associated with the deployment stemcell has diverged from the stemcells associated with the planner" do
              it 'it removes the given deployment from any stemcell it should not be associated with' do

                expect(stemcell_model.deployments).to include(deployment_model)
                expect(stemcell_model_2.deployments).to include(deployment_model)

                planner.update_stemcell_references!

                expect(stemcell_model.reload.deployments).to include(deployment_model)
                expect(stemcell_model_2.reload.deployments).to_not include(deployment_model)
              end
            end
          end
        end

        def setup_global_config_and_stubbing
          Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))
        end
      end
    end
  end
end
