require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Planner do
      subject { described_class.new('fake-dep-name', manifest_text, cloud_config) }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }
      let(:cloud_config) { Bosh::Director::Models::CloudConfig.create }
      let(:manifest_text) { Psych.dump minimal_manifest }
      def minimal_manifest
        {
          'name' => 'minimal',
          # 'director_uuid'  => 'deadbeef',

          'releases' => [{
              'name'    => 'appcloud',
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
            'canaries'          => 2,
            'canary_watch_time' => 4000,
            'max_in_flight'     => 1,
            'update_watch_time' => 20
          }
        }
      end


      describe 'parse' do
        it 'parses disk_pools' do
          manifest = minimal_manifest
          manifest['disk_pools'] = [
            {
              'name' => 'disk_pool1',
              'disk_size' => 3000,
            },
            {
              'name' => 'disk_pool2',
              'disk_size' => 1000,
            },
          ]
          planner = Planner.parse(manifest, cloud_config, {}, event_log, logger)
          expect(planner.disk_pools.length).to eq(2)
          expect(planner.disk_pool('disk_pool1').disk_size).to eq(3000)
          expect(planner.disk_pool('disk_pool2').disk_size).to eq(1000)
        end
      end

      describe '#initialize' do
        it 'raises an error if name is not given' do
          expect {
            described_class.new(nil, manifest_text, cloud_config, {})
          }.to raise_error(ArgumentError, 'name must not be nil')
        end

        describe 'options' do
          it 'should parse recreate' do
            plan = Planner.new('name', manifest_text, cloud_config, {})
            expect(plan.recreate).to eq(false)

            plan = Planner.new('name', manifest_text, cloud_config, 'recreate' => true)
            expect(plan.recreate).to eq(true)
          end
        end
      end

      describe '#bind_model' do
        describe 'binding deployment model' do
          it 'creates new deployment in DB using name from the manifest' do
            plan = make_plan('mycloud')

            expect(find_deployment('mycloud')).to be_nil
            plan.bind_model

            expect(plan.model).to eq(find_deployment('mycloud'))
            expect(Models::Deployment.count).to eq(1)
          end

          it 'uses an existing deployment model if found in DB' do
            plan = make_plan('mycloud')

            deployment = make_deployment('mycloud')
            plan.bind_model
            expect(plan.model).to eq(deployment)
            expect(Models::Deployment.count).to eq(1)
          end

          it 'enforces canonical name uniqueness' do
            make_deployment('my-cloud')
            plan = make_plan('my_cloud')

            expect {
              plan.bind_model
            }.to raise_error(DeploymentCanonicalNameTaken)

            expect(plan.model).to be_nil
            expect(Models::Deployment.count).to eq(1)
          end
        end

        describe 'getting VM models list' do
          it 'raises an error when deployment model is unbound' do
            plan = make_plan('my_cloud')

            expect {
              plan.vms
            }.to raise_error(DirectorError)

            make_deployment('mycloud')
            plan.bind_model
            expect { plan.vms }.to_not raise_error
          end

          it 'returns a list of VMs in deployment' do
            plan = make_plan('my_cloud')

            deployment = make_deployment('my_cloud')
            vm_model1 = Models::Vm.make(deployment: deployment)
            vm_model2 = Models::Vm.make(deployment: deployment)

            plan.bind_model
            expect(plan.vms).to eq([vm_model1, vm_model2])
          end
        end

        def make_plan(name)
          Planner.new(name, manifest_text, cloud_config, {})
        end

        def find_deployment(name)
          Models::Deployment.find(name: name)
        end

        def make_deployment(name)
          Models::Deployment.make(name: name)
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
        subject { Planner.parse(manifest, cloud_config,  {}, Config.event_log, Config.logger) }
        let(:manifest) do
          ManifestHelper.default_legacy_manifest(
            'releases' => [
              ManifestHelper.release('name' => 'same', 'version' => '123'),
              ManifestHelper.release('name' => 'new', 'version' => '123'),
            ]
          )
        end
        before { Bosh::Director::App.new(Bosh::Director::Config.load_file(asset('test-director-config.yml'))) }

        context 'given prior deployment with old release versions' do
          let(:stale_release_version) do
            release = Bosh::Director::Models::Release.create(name: 'stale')
            Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
          end
          let(:same_release_version) do
            release = Bosh::Director::Models::Release.create(name: 'same')
            Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
          end
          let(:new_release_version) do
            release = Bosh::Director::Models::Release.create(name: 'new')
            Bosh::Director::Models::ReleaseVersion.create(release: release, version: '123')
          end
          let(:assembler) { Assembler.new subject }

          before do
            expect(new_release_version).to exist
            old_deployment = Bosh::Director::Models::Deployment.create(name: manifest['name'])
            old_deployment.add_release_version stale_release_version
            old_deployment.add_release_version same_release_version
            assembler.bind_deployment
            assembler.bind_releases
          end

          it 'updates the release version on the deployment to be the ones from the provided manifest' do
            deployment = subject.model

            expect(deployment.release_versions).to include(stale_release_version)
            subject.persist_updates!
            expect(deployment.release_versions).to_not include(stale_release_version)
            expect(deployment.release_versions).to include(same_release_version)
            expect(deployment.release_versions).to include(new_release_version)
          end

          it 'locks the stale releases when removing them' do
            expect(subject).to receive(:with_release_locks).with(['stale'])
            subject.persist_updates!
          end

          it 'saves the deployment model' do
            deployment = subject.model
            deployment.name = 'new-deployment-name'
            subject.persist_updates!
            expect(deployment.reload.name).to eq('new-deployment-name')
          end
        end
      end

      describe '#update_stemcell_references!' do
        subject { Planner.parse(manifest, cloud_config,  {}, Config.event_log, Config.logger) }
        let(:manifest) { ManifestHelper.default_legacy_manifest }
        before { Bosh::Director::App.new(Bosh::Director::Config.load_file(asset('test-director-config.yml'))) }

        context "when the stemcells associated with the resource pools have diverged from the stemcells associated with the planner" do
          let(:stemcell_model_1) { Bosh::Director::Models::Stemcell.create(name: 'default', version: '1', cid: 'abc') }
          let(:stemcell_model_2) { Bosh::Director::Models::Stemcell.create(name: 'stem2', version: '1.0', cid: 'def') }

          before do
            old_deployment = Bosh::Director::Models::Deployment.create(name: manifest['name'])
            old_deployment.add_stemcell stemcell_model_1
            old_deployment.add_stemcell stemcell_model_2
            assembler = Assembler.new(subject)
            assembler.bind_deployment
            assembler.bind_stemcells
          end

          it 'it removes the given deployment from any stemcell it should not be associated with' do
            deployment_model = subject.model
            expect(stemcell_model_1.deployments).to include(deployment_model)
            expect(stemcell_model_2.deployments).to include(deployment_model)

            subject.update_stemcell_references!

            expect(stemcell_model_1.reload.deployments).to include(deployment_model)
            expect(stemcell_model_2.reload.deployments).to_not include(deployment_model)
          end
        end
      end
    end
  end
end
