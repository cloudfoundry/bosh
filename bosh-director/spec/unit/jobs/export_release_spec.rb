require 'spec_helper'

module Bosh::Director
  describe Jobs::ExportRelease do
    let(:snapshots) { [Models::Snapshot.make(snapshot_cid: 'snap0'), Models::Snapshot.make(snapshot_cid: 'snap1')] }

    subject(:job) { described_class.new("deployment_name", "release_name", "release_version", "stemcell_os", "stemcell_version") }

    def create_stemcell
      Bosh::Director::Models::Stemcell.create(
          name: 'my-stemcell-with-a-name',
          version: 'stemcell_version',
          operating_system: 'stemcell_os',
          cid: 'cloud-id-a',
      )
    end

    it 'raises an error when the targeted deployment is not found' do
      create_stemcell
      expect {
        job.perform
      }.to raise_error(Bosh::Director::DeploymentNotFound)
    end

    context 'with a valid deployment targeted' do
      let(:deployment_manager) { instance_double(Api::DeploymentManager) }
      let(:targeted_deployment) { Models::Deployment.create({name: "deployment_name", cloud_config: cloud_config_model}) }
      let(:cloud_config_model) { Models::CloudConfig.create({}) }

      before {
        cloud_config_model.manifest = {
            "compilation" => {
                "workers" => 1,
            },
            "networks" => [{
                               "name" => "dummy-network",
                           }]
        }
        cloud_config_model.save

        allow(Api::DeploymentManager).to receive(:new).and_return(deployment_manager)
        allow(deployment_manager).to receive(:find_by_name).and_return(targeted_deployment)
      }

      it 'raises an error when the requested release does not exist' do
        create_stemcell
        expect {
          job.perform
        }.to raise_error(Bosh::Director::ReleaseNotFound)
      end

      context 'when the requested release exists but release version does not exist' do
        before {
          Bosh::Director::Models::Release.create(name: 'release_name')
        }

        it 'fails with the expected error' do
          create_stemcell
          expect {
            job.perform
          }.to raise_error(Bosh::Director::ReleaseVersionNotFound)
        end
      end

      context 'when the requested release and version exist' do
        before {
          release = Bosh::Director::Models::Release.create(name: 'release_name')
          release_version = release.add_version(:version => 'release_version')
          release_version.add_template(
          :name => 'template_a',
          :version => 'template_a_version',
          :release_id => release.id,
          :blobstore_id => 'template_a_blobstore_id',
          :sha1 => 'template_a_sha1',
          :package_names_json => '["release_a_package"]')
          release_version.add_template(
          :name => 'template_b',
          :version => 'template_b_version',
          :release_id => release.id,
          :blobstore_id => 'template_b_blobstore_id',
          :sha1 => 'template_b_sha1',
          :package_names_json => '["release_b_package"]')
        }

        it 'raises an error if the requested stemcell is not found' do
          expect {
            job.perform
          }.to raise_error(Bosh::Director::StemcellNotFound)
        end

        context 'and the requested stemcell is found' do
          let(:package_compile_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep)}
          let(:stemcell) { Bosh::Director::Models::Stemcell.find(name: 'my-stemcell-with-a-name') }
          let(:planner) { instance_double(Bosh::Director::DeploymentPlan::Planner) }

          before {
            create_stemcell
            allow(Api::DeploymentManager).to receive(:new).and_return(deployment_manager)
            allow(deployment_manager).to receive(:find_by_name).and_return(targeted_deployment)
            allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:new).and_return(package_compile_step)
            allow(job).to receive(:create_planner).and_return(planner)
            allow(Config).to receive(:cloud)
            allow(Config).to receive(:event_log)
          }

          it 'locks the deployment, release, and selected stemcell' do
            allow(package_compile_step).to receive(:perform)

            lock_timeout = {:timeout=>900} # 15 minutes. 15 * 60
            expect(job).to receive(:with_deployment_lock).with('deployment_name', lock_timeout).and_yield
            expect(job).to receive(:with_release_lock).with('release_name', lock_timeout).and_yield
            expect(job).to receive(:with_stemcell_lock).with('my-stemcell-with-a-name', 'stemcell_version', lock_timeout).and_yield

            job.perform
          end

          it 'succeeds' do
            expect(DeploymentPlan::Steps::PackageCompileStep).to receive(:new).with(planner, Config.cloud, Config.logger, Config.event_log, job)
            expect(package_compile_step).to receive(:perform).with no_args

            job.perform
          end

          context 'and multiple stemcells match the requested stemcell' do
            before {
              Bosh::Director::Models::Stemcell.create(
                  name: 'my-stemcell-with-b-name',
                  version: 'stemcell_version',
                  operating_system: 'stemcell_os',
                  cid: 'cloud-id-b',
              )
            }

            it 'succeeds' do
              expect {
                job.validate_and_prepare
              }.to_not raise_error
            end

            it 'chooses the first stemcell alhpabetically by name' do
              job.validate_and_prepare
              expect(log_string).to match /Will compile with stemcell: my-stemcell-with-a-name/
            end
          end
        end
      end
    end
  end
end