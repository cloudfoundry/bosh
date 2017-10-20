require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DeploymentSpecParser do
    subject(:parser) { described_class.new(deployment, event_log, logger) }
    let(:deployment) { DeploymentPlan::Planner.new(planner_attributes, manifest_hash, cloud_config, deployment_model, planner_options) }
    let(:planner_options) { {} }
    let(:event_log) { Config.event_log }
    let(:cloud_config) { Models::Config.make(:cloud) }

    describe '#parse' do
      let(:options) { {} }
      let(:parsed_deployment) { subject.parse(manifest_hash, options) }
      let(:deployment_model) { Models::Deployment.make }
      let(:manifest_hash) do
        {
          'name' => 'deployment-name',
          'releases' => [],
          'networks' => [{ 'name' => 'network-name' }],
          'compilation' => {},
          'update' => {},
          'resource_pools' => [],
        }
      end
      let(:planner_attributes) {
        {
          name: manifest_hash['name'],
          properties: manifest_hash['properties'] || {}
        }
      }

      before { allow(DeploymentPlan::CompilationConfig).to receive(:new).and_return(compilation_config) }
      let(:compilation_config) { instance_double('Bosh::Director::DeploymentPlan::CompilationConfig') }

      before { allow(DeploymentPlan::UpdateConfig).to receive(:new).and_return(update_config) }
      let(:update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig') }

      describe 'name key' do
        it 'parses name' do
          manifest_hash.merge!('name' => 'Name with spaces')
          expect(parsed_deployment.name).to eq('Name with spaces')
        end

        it 'sets canonical name' do
          manifest_hash.merge!('name' => 'Name with spaces')
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
            stemcell_hash1 = {'alias' => 'stemcell1', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1]
          end

          it 'should not error out' do
            expect(parsed_deployment.stemcells.count).to eq(1)
          end

          it 'should error out if stemcell hash does not have alias' do
            manifest_hash['stemcells'].first.delete('alias')
            expect {
              parsed_deployment.stemcells
            }.to raise_error Bosh::Director::ValidationMissingField,
                "Required property 'alias' was not specified in object " +
                  '({"name"=>"bosh-aws-xen-hvm-ubuntu-trusty-go_agent", "version"=>"1234"})'
          end
        end

        context 'when there are stemcells with duplicate alias' do
          before do
            stemcell_hash1 = {'alias' => 'stemcell1', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1, stemcell_hash1]
          end

          it 'errors out when alias of stemcells are not unique' do
            expect {
              parsed_deployment.stemcells
            }.to raise_error Bosh::Director::StemcellAliasAlreadyExists, "Duplicate stemcell alias 'stemcell1'"
          end
        end

        context 'when there are stemcells with no OS nor name' do
          before do
            stemcell_hash1 = {'alias' => 'stemcell1', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1]
          end

          it 'errors out' do
            expect {
              parsed_deployment.stemcells
            }.to raise_error Bosh::Director::ValidationMissingField
          end
        end

        context 'when there are stemcells with OS' do
          before do
            stemcell_hash1 = {'alias' => 'stemcell1', 'os' => 'ubuntu-trusty', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1]
          end

          it 'should not errors out' do
            expect(parsed_deployment.stemcells.count).to eq(1)
            expect(parsed_deployment.stemcells['stemcell1'].os).to eq('ubuntu-trusty')
          end
        end

        context 'when there are stemcells with both name and OS' do
          before do
            stemcell_hash1 = {'alias' => 'stemcell1', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'os' => 'ubuntu-trusty', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash1]
          end

          it 'errors out' do
            expect {
              parsed_deployment.stemcells
            }.to raise_error Bosh::Director::StemcellBothNameAndOS
          end
        end

        context 'when there are 2 stemcells' do
          before do
            stemcell_hash0 = {'alias' => 'stemcell0', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'version' => '1234' }
            stemcell_hash1 = {'alias' => 'stemcell1', 'name' => 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent', 'version' => '1234' }
            manifest_hash['stemcells'] = [stemcell_hash0, stemcell_hash1]
          end

          it 'should add stemcells to deployment plan' do
            expect(parsed_deployment.stemcells.count).to eq(2)
          end
        end


      end

      describe 'properties key' do
        it 'parses basic properties' do
          manifest_hash.merge!('properties' => { 'foo' => 'bar' })
          expect(parsed_deployment.properties).to eq('foo' => 'bar')
        end

        it 'allows to not include properties key' do
          manifest_hash.delete('properties')
          expect(parsed_deployment.properties).to eq({})
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
            manifest_hash.merge!('release' => {'name' => 'rv-name', 'version' => 'abc'})
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
                {'name' => 'rv1-name', 'version' => 'abc'},
                {'name' => 'rv2-name', 'version' => 'def'},
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
                {'name' => 'same-name', 'version' => 'abc'},
                {'name' => 'same-name', 'version' => 'def'},
              ])
            end

            it 'raises an error' do
              expect {
                parsed_deployment
              }.to raise_error(/duplicate release name/i)
            end
          end
        end

        context "when both 'releases' and 'release' sections are specified" do
          before { manifest_hash.merge!('releases' => []) }
          before { manifest_hash.merge!('release' => {}) }

          it 'raises an error' do
            expect {
              parsed_deployment
            }.to raise_error(/use one of the two/)
          end
        end

        context "when neither 'releases' or 'release' section is specified" do
          before { manifest_hash.delete('releases') }
          before { manifest_hash.delete('release') }

          it 'raises an error' do
            expect {
              parsed_deployment
            }.to raise_error(
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

            expect(DeploymentPlan::UpdateConfig).to receive(:new).
              with('foo' => 'bar').
              and_return(update)

            expect(parsed_deployment.update).to eq(update)
          end

          context 'when canaries value is present in options' do
              let(:options) { { 'canaries'=> '42' } }
              it "replaces canaries value from job's update section with option's value" do
                expect(DeploymentPlan::UpdateConfig).to receive(:new)
                  .with( {'foo'=> 'bar', 'canaries' => '42'} )
                  .and_return(update_config)
                parsed_deployment.update
              end
          end
          context 'when max_in_flight value is present in options' do
            let(:options) { { 'max_in_flight'=> '42' } }
            it "replaces max_in_flight value from job's update section with option's value" do
              expect(DeploymentPlan::UpdateConfig).to receive(:new)
                .with( {'foo'=> 'bar', 'max_in_flight' => '42'} )
                .and_return(update_config)
              parsed_deployment.update
            end
          end
        end

        context 'when update section is not specified' do
          before { manifest_hash.delete('update') }

          it 'raises an error' do
            expect {
              parsed_deployment
            }.to raise_error(
              ValidationMissingField,
              /Required property 'update' was not specified in object .+/,
            )
          end
        end
      end

      shared_examples_for 'jobs/instance_groups key' do
        context 'when there is at least one job' do
          before { manifest_hash.merge!(keyword => []) }

          let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

          context 'when job names are unique' do
            before do
              manifest_hash.merge!(keyword => [
                { 'name' => 'instance-group-1-name' },
                { 'name' => 'instance-group-2-name' },
              ])
            end

            let(:instance_group_1) do
              instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
                name: 'instance-group-1-name',
                canonical_name: 'instance-group-1-canonical-name',
                jobs: []
              })
            end

            let(:instance_group_2) do
              instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
                name: 'instance-group-2-name',
                canonical_name: 'instance-group-2-canonical-name',
                jobs: []
              })
            end

            it 'delegates to Job to parse job specs' do
              expect(DeploymentPlan::InstanceGroup).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-1-name'}, event_log, logger, {}).
                and_return(instance_group_1)

              expect(DeploymentPlan::InstanceGroup).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-2-name'}, event_log, logger, {}).
                and_return(instance_group_2)

              expect(parsed_deployment.instance_groups).to eq([instance_group_1, instance_group_2])
            end

            context 'when canaries value is present in options' do
              let(:options) { { 'canaries'=> '42' } }
              it "replaces canaries value from job's update section with option's value" do
                expect(DeploymentPlan::InstanceGroup).to receive(:parse)
                  .with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-1-name'}, event_log, logger, options)
                  .and_return(instance_group_1)

                expect(DeploymentPlan::InstanceGroup).to receive(:parse).
                  with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-2-name'}, event_log, logger, options).
                  and_return(instance_group_2)

                parsed_deployment.instance_groups
              end
            end

            context 'when max_in_flight value is present in options' do
              let(:options) { { 'max_in_flight'=> '42' } }
              it "replaces max_in_flight value from job's update section with option's value" do
                expect(DeploymentPlan::InstanceGroup).to receive(:parse)
                   .with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-1-name'}, event_log, logger, options)
                   .and_return(instance_group_1)

                expect(DeploymentPlan::InstanceGroup).to receive(:parse).
                  with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-2-name'}, event_log, logger, options).
                  and_return(instance_group_2)

                parsed_deployment.instance_groups
              end
            end

            it 'allows to look up job by name' do
              allow(DeploymentPlan::InstanceGroup).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-1-name'}, event_log, logger, {}).
                and_return(instance_group_1)

              allow(DeploymentPlan::InstanceGroup).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-2-name'}, event_log, logger, {}).
                and_return(instance_group_2)


              expect(parsed_deployment.instance_group('instance-group-1-name')).to eq(instance_group_1)
              expect(parsed_deployment.instance_group('instance-group-2-name')).to eq(instance_group_2)
            end
          end

          context 'when more than one instance group have the same canonical name' do
            before do
              manifest_hash.merge!(keyword => [
                { 'name' => 'instance-group-1-name' },
                { 'name' => 'instance-group-2-name' },
              ])
            end

            let(:instance_group_1) do
              instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
                name: 'instance-group-1-name',
                canonical_name: 'same-canonical-name',
              })
            end

            let(:instance_group_2) do
              instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', {
                name: 'instance-group-2-name',
                canonical_name: 'same-canonical-name',
              })
            end

            it 'raises an error' do
              allow(DeploymentPlan::InstanceGroup).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-1-name'}, event_log, logger, {}).
                and_return(instance_group_1)

              allow(DeploymentPlan::InstanceGroup).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'instance-group-2-name'}, event_log, logger, {}).
                and_return(instance_group_2)

              expect {
                parsed_deployment
              }.to raise_error(
                DeploymentCanonicalJobNameTaken,
                "Invalid instance group name 'instance-group-2-name', canonical name already taken",
              )
            end
          end
        end

        context 'when there are no jobs' do
          before { manifest_hash.merge!(keyword => []) }

          it 'parses jobs and return empty array' do
            expect(parsed_deployment.instance_groups).to eq([])
          end
        end

        context 'when jobs key is not specified' do
          before { manifest_hash.delete(keyword) }

          it 'parses jobs and return empty array' do
            expect(parsed_deployment.instance_groups).to eq([])
          end
        end
      end

      describe 'jobs key' do
        let(:keyword) { "jobs" }
        it_behaves_like "jobs/instance_groups key"
      end

      describe 'instance_group key' do
        let(:keyword) { "instance_groups" }
        it_behaves_like "jobs/instance_groups key"

        context 'when there are both jobs and instance_groups' do
          before do
            manifest_hash.merge!('jobs' => [
                                     { 'name' => 'instance-group-1-name' },
                                     { 'name' => 'instance-group-2-name' },
                                 ],
                                 'instance_groups' => [
                                     { 'name' => 'instance-group-1-name' },
                                     { 'name' => 'instance-group-2-name' },
                                 ])
          end

          it 'throws an error' do
            expect {parsed_deployment}.to raise_error(JobBothInstanceGroupAndJob, "Deployment specifies both jobs and instance_groups keys, only one is allowed")
          end
        end
      end

      describe 'variables key' do
        context 'when variables spec is valid' do
          it 'parses provided variables' do
            variables_spec = [{'name' => 'var_a', 'type' => 'a'}, {'name' => 'var_b', 'type' => 'b', 'options' => {'x' => 2}}]
            manifest_hash.merge!('variables' => variables_spec)

            result_obj = parsed_deployment.variables

            expect(result_obj.spec.count).to eq(2)
            expect(result_obj.get_variable('var_a')).to eq({'name' => 'var_a', 'type' => 'a'})
            expect(result_obj.get_variable('var_b')).to eq({'name' => 'var_b', 'type' => 'b', 'options' => {'x' => 2}})
          end

          it 'allows to not include variables key' do
            result_obj = parsed_deployment.variables

            expect(result_obj.spec.count).to eq(0)
          end
        end

        context 'when variables spec is NOT valid' do
          it 'throws an error' do
            variables_spec = [{'name' => 'var_a', 'value' => 'a'}]
            manifest_hash.merge!('variables' => variables_spec)

            expect{ parsed_deployment.variables }.to raise_error Bosh::Director::VariablesInvalidFormat
          end
        end
      end

      describe 'features key' do
        context 'when features spec is valid' do
          it 'parses provided features' do
            features_spec = {'use_dns_addresses' => true}
            manifest_hash.merge!('features' => features_spec)

            features_obj = parsed_deployment.features
            expect(features_obj.use_dns_addresses).to eq(true)
          end
        end

        context 'when features spec is NOT valid' do
          it 'throws an error' do
            features_spec = {'use_dns_addresses' => 6}
            manifest_hash.merge!('features' => features_spec)

            expect{ parsed_deployment.features }.to raise_error Bosh::Director::FeaturesInvalidFormat
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
            addon_spec = [
                {
                  'name' => 'addon1',
                  'jobs' => [{'name' => 'dummy_with_properties', 'release' => 'dummy2'}, {'name' => 'dummy_with_package', 'release' => 'dummy2'}],
                  'properties' => {'dummy_with_properties' => {'echo_value' => 'addon_prop_value'}}
                }
            ]
            manifest_hash.merge!('releases' => [{'name' => 'dummy2', 'version' => '2'}]).merge!('addons' => addon_spec)

            result_obj = parsed_deployment.addons

            expect(result_obj.count).to eq(1)
            expect(result_obj.first.name).to eq('addon1')
            expect(result_obj.first.jobs).to eq([{'name' => 'dummy_with_properties', 'release' => 'dummy2', 'provides_links' => [], 'consumes_links' => [], 'properties' => nil},
              {'name' => 'dummy_with_package', 'release' => 'dummy2', 'provides_links' => [], 'consumes_links' => [], 'properties' => nil}])
            expect(result_obj.first.properties).to eq({'dummy_with_properties' => {'echo_value' => 'addon_prop_value'}})
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
                'jobs' => [{'name' => 'dummy_with_properties', 'release' => 'dummy2'}, {'name' => 'dummy_with_package', 'release' => 'dummy2'}],
                'properties' => {'dummy_with_properties' => {'echo_value' => 'addon_prop_value'}},
                'include' => {'deployments' => ['dep1']},
              }
            ]
            manifest_hash.merge!('releases' => [{'name' => 'dummy2', 'version' => '2'}]).merge!('addons' => addon_spec)

            expect{ parsed_deployment.addons }.to raise_error Bosh::Director::AddonDeploymentFilterNotAllowed
          end
        end
      end
    end
  end
end
