require 'rubygems'
require 'rubygems/package'
require 'spec_helper'

module Bosh::Director
  describe Jobs::ExportRelease do
    let(:snapshots) { [Models::Snapshot.make(snapshot_cid: 'snap0'), Models::Snapshot.make(snapshot_cid: 'snap1')] }

    subject(:job) { described_class.new('deployment_name', 'release_name', 'release_version', 'stemcell_os', 'stemcell_version') }

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

        targeted_deployment_manifest = <<-EOF
---
name: hello-go
director_uuid: d82978d9-c717-43e0-8f45-cc197f514cab
packages: {}
releases:
 - name: release-name
   version: 0+dev.3
        EOF

        allow(Api::DeploymentManager).to receive(:new).and_return(deployment_manager)
        allow(DeploymentPlan::PlannerFactory).to receive(:validate_packages)
        allow(deployment_manager).to receive(:find_by_name).and_return(targeted_deployment)
        allow(targeted_deployment).to receive(:manifest).and_return(targeted_deployment_manifest)

        allow(job).to receive(:with_deployment_lock).and_yield
        allow(job).to receive(:with_release_lock).and_yield
        allow(job).to receive(:with_stemcell_lock).and_yield
        allow(job).to receive(:deployment_manifest_has_release?).and_return(true)
      }

      it 'raises an error when the requested release does not exist' do
        create_stemcell
        expect {
          job.perform
        }.to raise_error(Bosh::Director::ReleaseNotFound)
      end

      it 'raises an error when exporting a release version not matching the manifest release version' do
        create_stemcell
        release = Bosh::Director::Models::Release.create(name: 'release_name')
        release.add_version(:version => 'release_version')
        allow(job).to receive(:deployment_manifest_has_release?).and_call_original
        expect {
          job.perform
        }.to raise_error(Bosh::Director::ReleaseNotMatchingManifest)
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
            allow(job).to receive(:create_tarball)
            allow(job).to receive(:result_file).and_return(Tempfile.new('result'))
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
            expect(job).to receive(:validate_release_packages)
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
              allow(package_compile_step).to receive(:perform)
            }

            it 'succeeds' do
              expect {
                job.perform
              }.to_not raise_error
            end

            it 'chooses the first stemcell alhpabetically by name' do
              job.perform
              expect(log_string).to match /Will compile with stemcell: my-stemcell-with-a-name/
            end
          end
        end
      end

      context 'when creating a tarball' do

        let(:blobstore_client) { instance_double('Bosh::Blobstore::BaseClient') }
        let(:archiver) { instance_double('Bosh::Director::Core::TarGzipper') }
        let(:package_compile_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep)}
        let(:planner) { instance_double(Bosh::Director::DeploymentPlan::Planner) }
        let(:task_dir) { Dir.mktmpdir }

        before {
          release = Bosh::Director::Models::Release.create(name: 'release_name')
          release_version = release.add_version(
              version: 'release_version',
              commit_hash: 'release_version_commit_hash',
              uncommitted_changes: 'false',
          )
          stemcell = Bosh::Director::Models::Stemcell.create(
              name: 'my-stemcell-with-a-name',
              version: 'stemcell_version',
              operating_system: 'stemcell_os',
              cid: 'cloud-id-a',
          )

          package_ruby = release_version.add_package(
              name: 'ruby',
              version: 'ruby_version',
              fingerprint: 'ruby_fingerprint',
              release_id: release.id,
              blobstore_id: 'ruby_package_blobstore_id',
              sha1: 'ruby_package_sha1',
              dependency_set_json: [],
          )
          package_ruby.add_compiled_package(
              sha1: 'ruby_compiled_package_sha1',
              blobstore_id: 'ruby_compiled_package_blobstore_id',
              stemcell_id: stemcell.id,
              dependency_key: [],
              build: 23,
          )

          package_postgres = release_version.add_package(
              name: 'postgres',
              version: 'postgres_version',
              fingerprint: 'postgres_fingerprint',
              release_id: release.id,
              blobstore_id: 'postgres_package_blobstore_id',
              sha1: 'postgres_package_sha1',
              dependency_set_json: Yajl::Encoder.encode(["ruby"]),
          )
          package_postgres.add_compiled_package(
              sha1: 'postgres_compiled_package_sha1',
              blobstore_id: 'postgres_package_blobstore_id',
              stemcell_id: stemcell.id,
              dependency_key: '[["ruby","ruby_version"]]',
              build: 23,
          )

          release_version.add_template(
              name: 'genisoimage',
              version: 'genisoimage_version',
              fingerprint: 'genisoimage_fingerprint',
              sha1: 'genisoimage_template_sha1',
              blobstore_id: 'genisoimage_blobstore_id',
              release_id: release.id,
              package_names_json: [],
          )

          result_file = double('result file')
          allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)
          allow(Bosh::Director::Core::TarGzipper).to receive(:new).and_return(archiver)
          allow(Config).to receive(:cloud)
          allow(Config).to receive(:event_log).and_return(EventLog::Log.new)
          allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:new).and_return(package_compile_step)
          allow(package_compile_step).to receive(:perform).with no_args
          allow(job).to receive(:create_planner).and_return(planner)
          allow(job).to receive(:result_file).and_return(result_file)
          allow(result_file).to receive(:write)
        }

        it 'should contain all compiled packages & jobs' do
          allow(archiver).to receive(:compress) { |download_dir, sources, output_path|

              files = Dir.entries(download_dir)
              expect(files).to include('compiled_packages', 'release.MF', 'jobs')

              files = Dir.entries(File.join(download_dir, 'compiled_packages'))
              expect(files).to include('postgres.tgz')

              files = Dir.entries(File.join(download_dir, 'jobs'))
              expect(files).to include('genisoimage.tgz')

              File.write(output_path, 'Some glorious content')
          }

          expect(blobstore_client).to receive(:create)
          expect(blobstore_client).to receive(:get).with('ruby_compiled_package_blobstore_id', anything, sha1: 'ruby_compiled_package_sha1')
          expect(blobstore_client).to receive(:get).with('postgres_package_blobstore_id', anything, sha1: 'postgres_compiled_package_sha1')
          expect(blobstore_client).to receive(:get).with('genisoimage_blobstore_id', anything, sha1: 'genisoimage_template_sha1')
          job.perform
        end

        it 'creates a manifest file that contains the sha1, fingerprint and blobstore_id' do
          allow(archiver).to receive(:compress) { |download_dir, sources, output_path|

             manifest_file = File.open(File.join(download_dir, 'release.MF'), 'r')
             manifest_file_content = manifest_file.read

             File.write(output_path, 'Some glorious content')

             expect(manifest_file_content).to eq(%q(---
compiled_packages:
- name: ruby
  version: ruby_version
  fingerprint: ruby_fingerprint
  sha1: ruby_compiled_package_sha1
  stemcell: stemcell_os/stemcell_version
  dependencies: []
- name: postgres
  version: postgres_version
  fingerprint: postgres_fingerprint
  sha1: postgres_compiled_package_sha1
  stemcell: stemcell_os/stemcell_version
  dependencies:
  - ruby
jobs:
- name: genisoimage
  version: genisoimage_version
  fingerprint: genisoimage_fingerprint
  sha1: genisoimage_template_sha1
commit_hash: release_version_commit_hash
uncommitted_changes: false
name: release_name
version: release_version
))}

          allow(blobstore_client).to receive(:get)
          allow(blobstore_client).to receive(:create)

          job.perform
        end

        it 'should put a tarball in the blobstore' do
          allow(blobstore_client).to receive(:get)
          allow(blobstore_client).to receive(:create).and_return("77da2388-ecf7-4cf6-be52-b054a07ea307")
          allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
             File.write(output_path, 'Some glorious content')
           }

          job.perform
        end
      end

    end
  end
end