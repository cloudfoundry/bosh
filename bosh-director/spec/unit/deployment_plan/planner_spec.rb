require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Planner do
      subject(:planner) { described_class.new(planner_attributes, minimal_manifest, cloud_config, deployment_model) }

      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }
      let(:cloud_config) { nil }
      let(:manifest_text) { generate_manifest_text }
      let(:planner_attributes) { {name: 'mycloud', properties: {}} }
      let(:deployment_model) { Models::Deployment.make }

      def generate_manifest_text
        Psych.dump minimal_manifest
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

      describe '#initialize' do
        it 'raises an error if name are not given' do
          planner_attributes.delete(:name)

          expect {
            planner
          }.to raise_error KeyError
        end

        describe 'options' do
          it 'should parse recreate' do
            expect(planner.recreate).to eq(false)

            plan = described_class.new(planner_attributes, manifest_text, cloud_config, deployment_model, 'recreate' => true)
            expect(plan.recreate).to eq(true)
          end
        end
      end

      its(:model) { deployment_model }

      describe 'vms' do
        it 'returns a list of VMs in deployment' do
          vm_model1 = Models::Vm.make(deployment: deployment_model)
          vm_model2 = Models::Vm.make(deployment: deployment_model)

          expect(planner.vms).to eq([vm_model1, vm_model2])
        end
      end

      describe '#jobs_starting_on_deploy' do
        before { subject.add_job(job1) }
        let(:job1) do
          instance_double('Bosh::Director::DeploymentPlan::Job', {
              name: 'fake-job1-name',
              canonical_name: 'fake-job1-cname',
            })
        end

        before { subject.add_job(job2) }
        let(:job2) do
          instance_double('Bosh::Director::DeploymentPlan::Job', {
              name: 'fake-job2-name',
              canonical_name: 'fake-job2-cname',
            })
        end

        context 'when there is at least one job that runs when deploy starts' do
          before { allow(job1).to receive(:starts_on_deploy?).with(no_args).and_return(false) }
          before { allow(job2).to receive(:starts_on_deploy?).with(no_args).and_return(true) }

          it 'only returns jobs that start on deploy' do
            expect(subject.jobs_starting_on_deploy).to eq([job2])
          end
        end

        context 'when there are no jobs that run when deploy starts' do
          before { allow(job1).to receive(:starts_on_deploy?).with(no_args).and_return(false) }
          before { allow(job2).to receive(:starts_on_deploy?).with(no_args).and_return(false) }

          it 'only returns jobs that start on deploy' do
            expect(subject.jobs_starting_on_deploy).to eq([])
          end
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
            Assembler.new(planner, nil, cloud_config,  {}, Config.event_log, Config.logger).bind_releases
          end

          it 'updates the release version on the deployment to be the ones from the provided manifest' do
            expect(deployment_model.release_versions).to include(stale_release_version)
            planner.persist_updates!
            expect(deployment_model.release_versions).to_not include(stale_release_version)
            expect(deployment_model.release_versions).to include(same_release_version)
            expect(deployment_model.release_versions).to include(new_release_version)
          end

          it 'locks the stale releases when removing them' do
            expect(subject).to receive(:with_release_locks).with(['stale','another_stale'])
            subject.persist_updates!
          end

          it 'de-dupes by release name when locking' do
            stale_release_version_124 = Bosh::Director::Models::ReleaseVersion.create(
                release: Bosh::Director::Models::Release.find(name: 'stale'),
                version: '124')
            deployment_model.add_release_version stale_release_version_124

            expect(subject).to receive(:with_release_locks).with(['stale','another_stale'])
            subject.persist_updates!
          end

          it 'saves original manifest' do
            original_manifest = generate_manifest_text
            minimal_manifest['update']['canaries'] = 10
            planner.persist_updates!
            expect(deployment_model.manifest).to eq(original_manifest)
          end
        end
      end

      describe '#update_stemcell_references!' do
        let(:manifest) { ManifestHelper.default_legacy_manifest }
        before do
          setup_global_config_and_stubbing
        end

        context "when the stemcells associated with the resource pools have diverged from the stemcells associated with the planner" do
          let(:stemcell_model_1) { Bosh::Director::Models::Stemcell.create(name: 'default', version: '1', cid: 'abc') }
          let(:stemcell_model_2) { Bosh::Director::Models::Stemcell.create(name: 'stem2', version: '1.0', cid: 'def') }

          before do
            deployment_model.add_stemcell(stemcell_model_1)
            deployment_model.add_stemcell(stemcell_model_2)
            stemcell_spec = {
              'name' => 'default',
              'cloud_properties' => {},
              'network' => 'default',
              'stemcell' => {
                'name' => 'default',
                'version' => '1'
              }
            }
            planner.add_network(Network.new(planner, {'name' => 'default'}))
            planner.add_resource_pool(ResourcePool.new(planner, stemcell_spec, logger))
            Assembler.new(planner, nil, cloud_config,  {}, Config.event_log, Config.logger).bind_stemcells
          end

          it 'it removes the given deployment from any stemcell it should not be associated with' do
            expect(stemcell_model_1.deployments).to include(deployment_model)
            expect(stemcell_model_2.deployments).to include(deployment_model)

            planner.update_stemcell_references!

            expect(stemcell_model_1.reload.deployments).to include(deployment_model)
            expect(stemcell_model_2.reload.deployments).to_not include(deployment_model)
          end
        end
      end

      def setup_global_config_and_stubbing
        Bosh::Director::App.new(Bosh::Director::Config.load_file(asset('test-director-config.yml')))
        allow(Bosh::Director::Config).to receive(:cloud) { instance_double(Bosh::Cloud) }
      end
    end
  end
end
