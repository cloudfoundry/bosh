require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::RuntimeConfigMerger do
    subject(:merger) { described_class.new(deployment) }

    describe '#RuntimeConfigMerger' do
      describe 'with deployment' do
        let(:cloud_config) { Models::CloudConfig.make }

        let(:deployment_model) do
          deployment_model = Models::Deployment.make
          deployment_model.cloud_config_id = cloud_config.id
          deployment_model.save
          deployment_model
        end

        let(:deployment_name) { 'dep1' }

        let(:manifest_hash) do
          manifest_hash = Bosh::Spec::Deployments.minimal_manifest
          manifest_hash['name'] = deployment_name
          manifest_hash
        end

        let(:deployment) do
          planner = DeploymentPlan::Planner.new({name: deployment_name, properties: {}}, manifest_hash, cloud_config, {}, deployment_model)
          planner.update = DeploymentPlan::UpdateConfig.new(manifest_hash['update'])
          planner
        end

        before do
          allow_any_instance_of(DeploymentPlan::Template).to receive(:bind_models)
          allow_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model)
        end

        describe '#add_releases' do
          let(:release_specs) { [{'name' => 'test_release_2', 'version' => '2'}] }

          it 'adds ReleaseVersion models to deployment for releases listed in runtime manifest' do
            expect_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).and_return(nil)

            subject.add_releases(release_specs)

            expect(deployment.release('test_release_2').version).to eq('2')
          end

          it 'raises RuntimeInvalidDeploymentRelease if deployment contains same release with different version than in runtime manifest' do
            deployment.add_release(DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'test_release_2', 'version' => '0.1'}))
            expect { subject.add_releases(release_specs) }.to raise_error(RuntimeInvalidDeploymentRelease)
          end

          it 'does not add a release that has already been added before' do
            subject.add_releases(release_specs)

            expect { subject.add_releases(release_specs) }.not_to raise_error
          end
        end

        describe '#merge_addon' do
          context 'when job does not exist in the database' do
            let(:addon) { Bosh::Spec::Deployments.runtime_config_with_addon['addons'].first }

            it 'should raise an error' do
              expect { subject.merge_addon(addon, []) }.to raise_error("Job 'dummy_with_properties' not found in Template table")
            end
          end

          context 'success' do
            let(:instance_groups_to_add_to) do
              instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
              instance_group_with_1_job = instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
              jobs = [{'name' => 'dummy', 'release' => 'dummy'}, {'name' => 'multi-monit-dummy', 'release' => 'dummy'}]
              instance_group_with_2_jobs = instance_group_parser.parse(Bosh::Spec::Deployments.simple_job(jobs: jobs))
              [instance_group_with_1_job, instance_group_with_2_jobs]
            end

            let(:release_model) { Bosh::Director::Models::Release.make(name: 'dummy') }
            let(:release_version_model) { Bosh::Director::Models::ReleaseVersion.make(version: '0.2-dev', release: release_model) }
            let(:runtime_config) { Bosh::Spec::Deployments.runtime_config_with_addon }
            let(:parsed_runtime_config) { DeploymentPlan::RuntimeManifestParser.new.parse(runtime_config) }

            before do
              release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy', release: release_model))
              release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'multi-monit-dummy', release: release_model))

              release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy_with_properties', release: release_model))
              release_version_model.add_template(Bosh::Director::Models::Template.make(name: 'dummy_with_package', release: release_model))

              release = DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'dummy', 'version' => '0.2-dev'})
              deployment.add_release(release)


              deployment.cloud_planner = DeploymentPlan::CloudManifestParser.new(logger)
                                             .parse(Bosh::Spec::Deployments.simple_cloud_config,
                                                    DeploymentPlan::GlobalNetworkResolver.new(deployment, [], logger),
                                                    DeploymentPlan::IpProviderFactory.new(true, logger))

              instance_groups_to_add_to.each { |ig| deployment.add_instance_group(ig) }
            end

            it 'should colocate addon jobs on instance groups' do
              expect_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).exactly(3).times

              subject.add_releases(parsed_runtime_config.releases)
              subject.merge_addon(parsed_runtime_config.addons.first, instance_groups_to_add_to)

              expect(deployment.instance_group('dummy').jobs.map(&:name)).to eq(['dummy', 'dummy_with_properties', 'dummy_with_package'])
              expect(deployment.instance_group('foobar').jobs.map(&:name)).to eq(['dummy', 'multi-monit-dummy', 'dummy_with_properties', 'dummy_with_package'])
            end

            context 'when addon job has the same name as an instance group job' do
              let(:instance_groups_to_add_to) do
                instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
                [instance_group_parser.parse(Bosh::Spec::Deployments.simple_job(jobs: ['name' => 'dummy_with_properties', 'release' => 'dummy']))]
              end

              it 'should raise an error' do
                subject.add_releases(parsed_runtime_config.releases)
                expect { subject.merge_addon(parsed_runtime_config.addons.first, instance_groups_to_add_to) }.to raise_error
                "Colocated job 'dummy_with_properties' is already added to the instance group 'dummy'."
              end
            end

            context 'when addons have properties' do
              let(:runtime_config) { Bosh::Spec::Deployments.runtime_config_with_addon }
              let(:instance_groups_to_add_to) do
                instance_group_parser = DeploymentPlan::InstanceGroupSpecParser.new(deployment, Config.event_log, logger)
                instance_group_without_properties = instance_group_parser.parse(Bosh::Spec::Deployments.dummy_job)
                jobs = [{'name' => 'dummy', 'release' => 'dummy'}]
                properties = {'instance_group_property' => 'value'}
                instance_group_with_properties = instance_group_parser.parse(Bosh::Spec::Deployments.simple_job(jobs: jobs, properties: properties))
                [instance_group_without_properties, instance_group_with_properties]
              end

              it 'should resolve job-scoped properties of addon jobs' do
                expect_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).exactly(3).times

                subject.add_releases(parsed_runtime_config.releases)
                subject.merge_addon(parsed_runtime_config.addons.first, instance_groups_to_add_to)

                dummy_job_properties = deployment.instance_group('dummy').all_properties
                foobar_job_properties = deployment.instance_group('foobar').all_properties

                expect(foobar_job_properties).to eq({'instance_group_property' => 'value', 'dummy_with_properties' => {'echo_value' => 'addon_prop_value'}})
                expect(dummy_job_properties).to eq({'dummy_with_properties' => {'echo_value' => 'addon_prop_value'}})
              end
            end

            context 'when addon jobs have job-scoped properties' do
              let(:runtime_config) do
                config = Bosh::Spec::Deployments.runtime_config_with_addon
                config['addons'][0]['jobs'][0]['properties'] = {'dummy_with_properties' => {'echo_value' => 'new_prop_value'}}
                config
              end

              it 'should resolve job-scoped properties of addon jobs' do
                expect_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).exactly(3).times

                subject.add_releases(parsed_runtime_config.releases)
                subject.merge_addon(parsed_runtime_config.addons.first, instance_groups_to_add_to)

                addon_template_scoped_properties = {'dummy' => {'dummy_with_properties' => {'echo_value' => 'new_prop_value'}}, 'foobar' => {'dummy_with_properties' => {'echo_value' => 'new_prop_value'}}}
                expect(deployment.instance_group('dummy').jobs.map(&:template_scoped_properties)).to eq([{}, addon_template_scoped_properties, {}])
                expect(deployment.instance_group('foobar').jobs.map(&:template_scoped_properties)).to eq([{}, {}, addon_template_scoped_properties, {}])
              end
            end

            context 'when there are links on the the addon job' do
              context 'when consumes_json and provides_json are "null"' do
                it 'does not throw an error' do
                  release_version_model.add_template(
                      Bosh::Director::Models::Template.make(name: 'dummy_with_properties', release: release_model, provides_json: 'null', consumes_json: 'null'))

                  expect {
                    subject.add_releases(parsed_runtime_config.releases)
                    subject.merge_addon(parsed_runtime_config.addons.first, instance_groups_to_add_to)
                  }.not_to raise_error
                end
              end

              before do
                bosh_release_model = Bosh::Director::Models::Release.make(name: 'bosh-release')
                bosh_release_version_model = Bosh::Director::Models::ReleaseVersion.make(version: '0+dev.1', release: bosh_release_model)
                bosh_release_version_model.add_template(
                    Bosh::Director::Models::Template.make(
                        name: 'addon',
                        release: bosh_release_model,
                        provides: [{'name' => 'api', 'type' => 'api'}],
                        consumes: [{'name' => 'db', 'type' => 'db'}]))
              end

              let(:parsed_runtime_config) do
                runtime_config = Bosh::Spec::Deployments.runtime_config_with_links
                runtime_config['addons'].first['jobs'].first.merge!({'provides' => {'api' => {'from' => 'api'}}})
                DeploymentPlan::RuntimeManifestParser.new.parse(runtime_config)
              end

              it 'should resolve links and colocate addon jobs on instance groups' do
                expect_any_instance_of(DeploymentPlan::ReleaseVersion).to receive(:bind_model).exactly(2).times
                expect_any_instance_of(DeploymentPlan::Template).to receive(:bind_models)

                subject.add_releases(parsed_runtime_config.releases)
                subject.merge_addon(parsed_runtime_config.addons.first, instance_groups_to_add_to)

                expect(deployment.instance_group('dummy').jobs.map(&:name)).to eq(['dummy', 'addon'])
                expect(deployment.instance_group('foobar').jobs.map(&:name)).to eq(['dummy', 'multi-monit-dummy', 'addon'])

                deployment.instance_groups.each do |ig|
                  addon_job = ig.templates.find { |t| t.name == 'addon' }
                  expect(addon_job.link_infos['dummy']).to eq(
                                                               {'consumes' => {'db' => {'name' => 'db', 'type' => 'db', 'from' => 'db'}},
                                                                'provides' => {'api' => {'name' => 'api', 'type' => 'api', 'from' => 'api'}}})
                end
              end
            end
          end
        end
      end
    end
  end
end