require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DeploymentSpecParser do
    subject(:parser) { described_class.new(deployment, event_log, per_spec_logger) }
    let(:deployment) do
      DeploymentPlan::Planner.new(
        manifest_hash['name'],
        manifest_hash,
        YAML.dump(manifest_hash),
        cloud_config,
        runtime_configs,
        deployment_model,
        planner_options,
      )
    end
    let(:planner_options) do
      {}
    end
    let(:event_log) { Config.event_log }
    let(:cloud_config) { FactoryBot.create(:models_config_cloud) }
    let(:runtime_configs) { [FactoryBot.create(:models_config_runtime)] }

    describe '#parse' do
      let(:options) do
        { 'is_deploy_action' => true }
      end
      let(:parsed_deployment) { subject.parse(manifest_hash, options) }
      let(:deployment_model) { FactoryBot.create(:models_deployment) }
      let(:manifest_hash) do
        {
          'name' => 'deployment-name',
          'releases' => [],
          'networks' => [{ 'name' => 'network-name' }],
          'compilation' => {},
          'update' => {},
        }
      end

      before { allow(DeploymentPlan::CompilationConfig).to receive(:new).and_return(compilation_config) }
      let(:compilation_config) { instance_double('Bosh::Director::DeploymentPlan::CompilationConfig') }

      before { allow(DeploymentPlan::UpdateConfig).to receive(:new).and_return(update_config) }
      let(:update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig') }

      before { allow(CloudFactory).to receive(:create).and_return(:cloud) }
      let(:cloud) { instance_double(CloudFactory) }

      describe 'name key' do
        it 'parses name' do
          manifest_hash['name'] = 'Name with spaces'
          expect(parsed_deployment.name).to eq('Name with spaces')
        end

        it 'sets canonical name' do
          manifest_hash['name'] = 'Name with spaces'
          expect(parsed_deployment.canonical_name).to eq('namewithspaces')
        end
      end

      describe 'stemcells' do
        context 'when no top level stemcells' do
          before do
            manifest_hash.delete('stemcells')
          end

          it 'should not error out' do
            expect(parsed_deployment.stemcells).to eq({})
          end
        end

        context 'when there 1 stemcell' do
          before do
            stemcell_hash1 = { 'alias' => 'stemcell1', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1]
          end

          it 'should not error out' do
            expect(parsed_deployment.stemcells.count).to eq(1)
          end

          it 'should error out if stemcell hash does not have alias' do
            manifest_hash['stemcells'].first.delete('alias')
            expect do
              parsed_deployment.stemcells
            end.to raise_error Bosh::Director::ValidationMissingField,
                               "Required property 'alias' was not specified in object " \
                               '({"name"=>"bosh-aws-xen-hvm-ubuntu-trusty-go_agent", "version"=>"1234"})'
          end
        end

        context 'when there are stemcells with duplicate alias' do
          before do
            stemcell_hash1 = { 'alias' => 'stemcell1', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1, stemcell_hash1]
          end

          it 'errors out when alias of stemcells are not unique' do
            expect do
              parsed_deployment.stemcells
            end.to raise_error Bosh::Director::StemcellAliasAlreadyExists, "Duplicate stemcell alias 'stemcell1'"
          end
        end

        context 'when there are stemcells with no OS nor name' do
          before do
            stemcell_hash1 = { 'alias' => 'stemcell1', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1]
          end

          it 'errors out' do
            expect do
              parsed_deployment.stemcells
            end.to raise_error Bosh::Director::ValidationMissingField
          end
        end

        context 'when there are stemcells with OS' do
          before do
            stemcell_hash1 = { 'alias' => 'stemcell1', 'os' => 'ubuntu-trusty', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1]
          end

          it 'should not errors out' do
            expect(parsed_deployment.stemcells.count).to eq(1)
            expect(parsed_deployment.stemcells['stemcell1'].os).to eq('ubuntu-trusty')
          end
        end

        context 'when there are 2 stemcells' do
          before do
            stemcell_hash0 = { 'alias' => 'stemcell0', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'version' => '1234' }
            stemcell_hash1 = { 'alias' => 'stemcell1', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash0, stemcell_hash1]
          end

          it 'should add stemcells to deployment plan' do
            expect(parsed_deployment.stemcells.count).to eq(2)
          end
        end
      end

      describe 'releases/release key' do
        let(:releases_spec) do
          [
            { 'name' => 'foo', 'version' => '27' },
            { 'name' => 'bar', 'version' => '42' },
          ]
        end

        context "when 'release' section is specified" do
          before do
            manifest_hash.delete('releases')
            manifest_hash.merge!('release' => { 'name' => 'rv-name', 'version' => 'abc' })
          end

          it 'delegates to ReleaseVersion' do
            expect(parsed_deployment.releases.size).to eq(1)
            release_version = parsed_deployment.releases.first
            expect(release_version).to be_a(DeploymentPlan::ReleaseVersion)
            expect(release_version.name).to eq('rv-name')
          end

          it 'allows to look up release by name' do
            release_version = parsed_deployment.release('rv-name')
            expect(release_version).to be_a(DeploymentPlan::ReleaseVersion)
            expect(release_version.name).to eq('rv-name')
          end
        end

        context "when 'releases' section is specified" do
          before { manifest_hash.delete('release') }

          context 'when non-duplicate releases are included' do
            before do
              manifest_hash.merge!('releases' => [
                                     { 'name' => 'rv1-name', 'version' => 'abc' },
                                     { 'name' => 'rv2-name', 'version' => 'def' },
                                   ])
            end

            it 'delegates to ReleaseVersion' do
              expect(parsed_deployment.releases.size).to eq(2)

              rv1 = parsed_deployment.releases.first
              expect(rv1).to be_a(DeploymentPlan::ReleaseVersion)
              expect(rv1.name).to eq('rv1-name')
              expect(rv1.version).to eq('abc')

              rv2 = parsed_deployment.releases.last
              expect(rv2).to be_a(DeploymentPlan::ReleaseVersion)
              expect(rv2.name).to eq('rv2-name')
              expect(rv2.version).to eq('def')
            end

            it 'allows to look up release by name' do
              rv1 = parsed_deployment.release('rv1-name')
              expect(rv1).to be_a(DeploymentPlan::ReleaseVersion)
              expect(rv1.name).to eq('rv1-name')
              expect(rv1.version).to eq('abc')

              rv2 = parsed_deployment.release('rv2-name')
              expect(rv2).to be_a(DeploymentPlan::ReleaseVersion)
              expect(rv2.name).to eq('rv2-name')
              expect(rv2.version).to eq('def')
            end
          end

          context 'when duplicate releases are included' do
            before do
              manifest_hash.merge!('releases' => [
                                     { 'name' => 'same-name', 'version' => 'abc' },
                                     { 'name' => 'same-name', 'version' => 'def' },
                                   ])
            end

            it 'raises an error' do
              expect do
                parsed_deployment
              end.to raise_error(/duplicate release name/i)
            end
          end
        end

        context "when both 'releases' and 'release' sections are specified" do
          before { manifest_hash.merge!('releases' => []) }
          before { manifest_hash.merge!('release' => {}) }

          it 'raises an error' do
            expect do
              parsed_deployment
            end.to raise_error(/use one of the two/)
          end
        end

        context "when neither 'releases' or 'release' section is specified" do
          before { manifest_hash.delete('releases') }
          before { manifest_hash.delete('release') }

          it 'raises an error' do
            expect do
              parsed_deployment
            end.to raise_error(
              ValidationMissingField,
              /Required property 'releases' was not specified in object .+/,
            )
          end
        end
      end

      describe 'update key' do
        context 'when update section is specified' do
          before { manifest_hash.merge!('update' => { 'foo' => 'bar' }) }

          it 'delegates parsing to UpdateConfig' do
            update = instance_double('Bosh::Director::DeploymentPlan::UpdateConfig')

            expect(DeploymentPlan::UpdateConfig).to receive(:new)
              .with({ 'foo' => 'bar', 'is_deploy_action' => true })
              .and_return(update)

            expect(parsed_deployment.update).to eq(update)
          end

          context 'when canaries value is present in options' do
            let(:options) do
              { 'is_deploy_action' => true, 'canaries' => '42' }
            end
            it "replaces canaries value from job's update section with option's value" do
              expect(DeploymentPlan::UpdateConfig).to receive(:new)
                .with({ 'foo' => 'bar', 'is_deploy_action' => true, 'canaries' => '42' })
                .and_return(update_config)
              parsed_deployment.update
            end
          end
          context 'when max_in_flight value is present in options' do
            let(:options) do
              { 'is_deploy_action' => true, 'max_in_flight' => '42' }
            end
            it "replaces max_in_flight value from job's update section with option's value" do
              expect(DeploymentPlan::UpdateConfig).to receive(:new)
                .with({ 'foo' => 'bar', 'is_deploy_action' => true, 'max_in_flight' => '42' })
                .and_return(update_config)
              parsed_deployment.update
            end
          end
        end

        context 'when update section is not specified' do
          before { manifest_hash.delete('update') }

          it 'raises an error' do
            expect do
              parsed_deployment
            end.to raise_error(
              ValidationMissingField,
              /Required property 'update' was not specified in object .+/,
            )
          end
        end
      end

      describe 'instance_groups key' do
        context 'when there is at least one instance_group' do
          before { manifest_hash.merge!('instance_groups' => []) }

          let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

          context 'when instance group names are unique' do
            before do
              manifest_hash.merge!('instance_groups' => [
                                     { 'name' => 'instance-group-1-name' },
                                     { 'name' => 'instance-group-2-name' },
                                   ])
            end

            let(:instance_group_1) do
              instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                              name: 'instance-group-1-name',
                              canonical_name: 'instance-group-1-canonical-name',
                              jobs: [])
            end

            let(:instance_group_2) do
              instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                              name: 'instance-group-2-name',
                              canonical_name: 'instance-group-2-canonical-name',
                              jobs: [])
            end

            it 'delegates to InstanceGroup to parse instance group specs' do
              expect(DeploymentPlan::InstanceGroup).to receive(:parse)
                .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-1-name' }, event_log, per_spec_logger, { 'is_deploy_action' => true })
                .and_return(instance_group_1)

              expect(DeploymentPlan::InstanceGroup).to receive(:parse)
                .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-2-name' }, event_log, per_spec_logger, { 'is_deploy_action' => true })
                .and_return(instance_group_2)

              expect(parsed_deployment.instance_groups).to eq([instance_group_1, instance_group_2])
            end

            context 'when canaries value is present in options' do
              let(:options) do
                { 'is_deploy_action' => true, 'canaries' => '42' }
              end
              it "replaces canaries value from instance group's update section with option's value" do
                expect(DeploymentPlan::InstanceGroup).to receive(:parse)
                  .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-1-name' }, event_log, per_spec_logger, options)
                  .and_return(instance_group_1)

                expect(DeploymentPlan::InstanceGroup).to receive(:parse)
                  .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-2-name' }, event_log, per_spec_logger, options)
                  .and_return(instance_group_2)

                parsed_deployment.instance_groups
              end
            end

            context 'when max_in_flight value is present in options' do
              let(:options) do
                { 'is_deploy_action' => true, 'max_in_flight' => '42' }
              end
              it "replaces max_in_flight value from instance group's update section with option's value" do
                expect(DeploymentPlan::InstanceGroup).to receive(:parse)
                  .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-1-name' }, event_log, per_spec_logger, options)
                  .and_return(instance_group_1)

                expect(DeploymentPlan::InstanceGroup).to receive(:parse)
                  .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-2-name' }, event_log, per_spec_logger, options)
                  .and_return(instance_group_2)

                parsed_deployment.instance_groups
              end
            end

            it 'allows to look up instance group by name' do
              allow(DeploymentPlan::InstanceGroup).to receive(:parse)
                .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-1-name' }, event_log, per_spec_logger, { 'is_deploy_action' => true })
                .and_return(instance_group_1)

              allow(DeploymentPlan::InstanceGroup).to receive(:parse)
                .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-2-name' }, event_log, per_spec_logger, { 'is_deploy_action' => true })
                .and_return(instance_group_2)

              expect(parsed_deployment.instance_group('instance-group-1-name')).to eq(instance_group_1)
              expect(parsed_deployment.instance_group('instance-group-2-name')).to eq(instance_group_2)
            end
          end

          context 'when more than one instance group have the same canonical name' do
            before do
              manifest_hash.merge!('instance_groups' => [
                                     { 'name' => 'instance-group-1-name' },
                                     { 'name' => 'instance-group-2-name' },
                                   ])
            end

            let(:instance_group_1) do
              instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                              name: 'instance-group-1-name',
                              vm_type: 'default',
                              canonical_name: 'same-canonical-name')
            end

            let(:instance_group_2) do
              instance_double('Bosh::Director::DeploymentPlan::InstanceGroup',
                              name: 'instance-group-2-name',
                              vm_type: 'default',
                              canonical_name: 'same-canonical-name')
            end

            it 'raises an error' do
              allow(DeploymentPlan::InstanceGroup).to receive(:parse)
                .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-1-name' }, event_log, per_spec_logger, { 'is_deploy_action' => true })
                .and_return(instance_group_1)

              allow(DeploymentPlan::InstanceGroup).to receive(:parse)
                .with(be_a(DeploymentPlan::Planner), { 'name' => 'instance-group-2-name' }, event_log, per_spec_logger, { 'is_deploy_action' => true })
                .and_return(instance_group_2)

              expect do
                parsed_deployment
              end.to raise_error(
                DeploymentCanonicalJobNameTaken,
                "Invalid instance group name 'instance-group-2-name', canonical name already taken",
              )
            end
          end
        end

        context 'when there are no instance groups' do
          before { manifest_hash.merge!('instance_groups' => []) }

          it 'parses instance groups and return empty array' do
            expect(parsed_deployment.instance_groups).to eq([])
          end
        end

        context 'when instance groups key is not specified' do
          before { manifest_hash.delete('instance_groups') }

          it 'parses instance groups and return empty array' do
            expect(parsed_deployment.instance_groups).to eq([])
          end
        end
      end

      describe 'variables key' do
        context 'when variables spec is valid' do
          it 'parses provided variables' do
            variables_spec = [{ 'name' => 'var_a', 'type' => 'a' }, { 'name' => 'var_b', 'type' => 'b', 'options' => { 'x' => 2 } }]
            manifest_hash['variables'] = variables_spec

            result_obj = parsed_deployment.variables

            expect(result_obj.spec.count).to eq(2)
            expect(result_obj.get_variable('var_a')).to eq('name' => 'var_a', 'type' => 'a')
            expect(result_obj.get_variable('var_b')).to eq('name' => 'var_b', 'type' => 'b', 'options' => { 'x' => 2 })
          end

          it 'allows to not include variables key' do
            result_obj = parsed_deployment.variables

            expect(result_obj.spec.count).to eq(0)
          end
        end

        context 'when variables spec is NOT valid' do
          it 'throws an error' do
            variables_spec = [{ 'name' => 'var_a', 'value' => 'a' }]
            manifest_hash['variables'] = variables_spec

            expect { parsed_deployment.variables }.to raise_error Bosh::Director::VariablesInvalidFormat
          end
        end
      end

      describe 'features key' do
        context 'when features spec is valid' do
          it 'parses provided features' do
            features_spec = { 'use_dns_addresses' => true }
            manifest_hash['features'] = features_spec

            features_obj = parsed_deployment.features
            expect(features_obj.use_dns_addresses).to eq(true)
          end
        end

        context 'when features spec is NOT valid' do
          it 'throws an error' do
            features_spec = { 'use_dns_addresses' => 6 }
            manifest_hash['features'] = features_spec

            expect { parsed_deployment.features }.to raise_error Bosh::Director::FeaturesInvalidFormat
          end
        end

        context 'when features spec is NOT specified' do
          it 'defaults features object' do
            features_obj = parsed_deployment.features
            expect(features_obj.use_dns_addresses).to be_nil
          end
        end
      end

      describe 'addons' do
        context 'when addon spec is valid' do
          it 'parses provided addons' do
            manifest_hash.merge!(SharedSupport::DeploymentManifestHelper.runtime_config_with_addon)

            result_obj = parsed_deployment.addons

            expect(result_obj.count).to eq(1)
            expect(result_obj.first.name).to eq('addon1')
            expect(result_obj.first.jobs).to eq(
              [
                {
                  'name' => 'dummy_with_properties',
                  'release' => 'dummy2',
                  'provides' => {},
                  'consumes' => {},
                  'properties' => {
                    'dummy_with_properties' => {
                      'echo_value' => 'addon_prop_value',
                    },
                  },
                },
                {
                  'name' => 'dummy_with_package',
                  'release' => 'dummy2',
                  'provides' => {},
                  'consumes' => {},
                  'properties' => nil,
                },
              ],
            )
          end

          it 'allows to not include addons' do
            result_obj = parsed_deployment.addons

            expect(result_obj.count).to eq(0)
          end
        end

        context 'when addon spec is NOT valid' do
          it 'throws an error' do
            addon_spec = [
              {
                'name' => 'addon1',
                'jobs' => [{ 'name' => 'dummy_with_properties', 'release' => 'dummy2' }, { 'name' => 'dummy_with_package', 'release' => 'dummy2' }],
                'properties' => { 'dummy_with_properties' => { 'echo_value' => 'addon_prop_value' } },
                'include' => { 'deployments' => ['dep1'] },
              },
            ]
            manifest_hash.merge!('releases' => [{ 'name' => 'dummy2', 'version' => '2' }])['addons'] = addon_spec

            expect { parsed_deployment.addons }.to raise_error Bosh::Director::AddonDeploymentFilterNotAllowed
          end
        end
      end
    end
  end
end
