require 'rubygems'
require 'rubygems/package'
require 'spec_helper'

module Bosh::Director
  describe Jobs::ExportRelease do
    include Support::FakeLocks
    before do
      fake_locks
      Bosh::Director::Config.current_job = job
      allow(Bosh::Director::Config).to receive(:dns_enabled?) { false }
      Bosh::Director::Config.current_job.task_id = 'fake-task-id'
      allow(job).to receive(:task_cancelled?) { false }
      allow(Config).to receive(:cloud)
      blobstore = double(:blobstore)
      blobstores = instance_double(Bosh::Director::Blobstores, blobstore: blobstore)
      app = instance_double(App, blobstores: blobstores)
      allow(App).to receive(:instance).and_return(app)
    end

    subject(:job) { described_class.new(deployment_manifest['name'], release_name, manifest_release_version, 'ubuntu', '1') }

    def create_stemcell
      Bosh::Director::Models::Stemcell.create(
          name: 'ubuntu-stemcell',
          version: '1',
          operating_system: 'ubuntu',
          cid: 'cloud-id-a',
      )
    end

    let(:release_name) { deployment_manifest['releases'].first['name'] }
    let(:manifest_release_version) { deployment_manifest['releases'].first['version'] }
    let(:deployment_manifest) { Bosh::Spec::Deployments.simple_manifest }

    it 'raises an error when the targeted deployment is not found' do
      create_stemcell
      expect {
        job.perform
      }.to raise_error(Bosh::Director::DeploymentNotFound)
    end

    context 'with a valid deployment targeted' do

      let(:cloud_config) { Bosh::Spec::Deployments.simple_cloud_config }

      let!(:deployment_model) do
        Models::Deployment.make(
          name: deployment_manifest['name'],
          manifest: YAML.dump(deployment_manifest),
          cloud_config: Models::CloudConfig.make(manifest: cloud_config)
        )
      end

      it 'raises an error when the requested release does not exist' do
        create_stemcell
        expect {
          job.perform
        }.to raise_error(Bosh::Director::ReleaseNotFound)
      end

      before do
        allow(job).to receive(:with_deployment_lock).and_yield
        allow(job).to receive(:with_release_lock).and_yield
        allow(job).to receive(:with_stemcell_lock).and_yield
      end

      context 'when the requested release exists but version does not match' do
        it 'raises an error' do
          create_stemcell
          release = Bosh::Director::Models::Release.create(name: release_name)
          release.add_version(:version => '0.2-dev')
          expect {
            job.perform
          }.to raise_error(Bosh::Director::ReleaseVersionNotFound)
        end
      end

      context 'when the requested release exists but exporting version does not match' do
        let(:manifest_release_version) { '0.5-dev' }
        let(:exported_release_version) { '0.1-dev' }

        it 'raises an error' do
          create_stemcell
          release = Bosh::Director::Models::Release.create(name: release_name)
          release.add_version(:version => exported_release_version)
          release.add_version(:version => manifest_release_version)
          expect {
            job.perform
          }.to raise_error(Bosh::Director::ReleaseNotMatchingManifest)
        end
      end

      context 'when the requested release and version exist' do
        before do
          release = Bosh::Director::Models::Release.create(name: release_name)
          release_version = release.add_version(:version => '0.1-dev')
          release_version.add_package(Bosh::Director::Models::Package.make(name: 'foo'))
          release_version.add_package(Bosh::Director::Models::Package.make(name: 'bar'))
          release_version.add_template(
            :name => deployment_manifest['jobs'].first['templates'].first['name'],
            :version => 'template_a_version',
            :release_id => release.id,
            :blobstore_id => 'template_a_blobstore_id',
            :sha1 => 'template_a_sha1',
            :package_names_json => '["foo", "bar"]')
        end

        it 'raises an error if the requested stemcell is not found' do
          expect {
            job.perform
          }.to raise_error(Bosh::Director::StemcellNotFound)
        end

        context 'and the requested stemcell is found' do
          let(:package_compile_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep)}

          before do
            create_stemcell
            allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:new).and_return(package_compile_step)
            allow(job).to receive(:create_tarball)
            allow(job).to receive(:result_file).and_return(Tempfile.new('result'))
            allow(package_compile_step).to receive(:perform)
          end

          it 'locks the deployment, release, and selected stemcell' do
            lock_timeout = {:timeout=>900} # 15 minutes. 15 * 60
            expect(job).to receive(:with_deployment_lock).with(deployment_manifest['name'], lock_timeout).and_yield
            expect(job).to receive(:with_release_lock).with(release_name, lock_timeout).and_yield
            expect(job).to receive(:with_stemcell_lock).with('ubuntu-stemcell', '1', lock_timeout).and_yield

            job.perform
          end

          it 'succeeds' do
            expect(DeploymentPlan::Steps::PackageCompileStep).to receive(:new) do |job, config, _, _|
              expect(job.first).to be_instance_of(DeploymentPlan::Job)
              expect(job.first.release.name).to eq(release_name)
              expect(config).to be_instance_of(DeploymentPlan::CompilationConfig)
            end.and_return(package_compile_step)
            expect(package_compile_step).to receive(:perform).with no_args

            job.perform
          end

          context 'when using vm_types, stemcells, and azs' do
            let(:cloud_config) do
              config = Bosh::Spec::Deployments.simple_cloud_config
              config.delete('resource_pools')
              config['azs'] = [{'name' => 'z1', 'cloud_properties' => {}}]
              config['networks'].first['subnets'].first['az'] = 'z1'
              config['vm_types'] =  [Bosh::Spec::Deployments.vm_type]
              config['compilation']['az'] = 'z1'
              config
            end

            let(:deployment_manifest) do
              manifest = Bosh::Spec::Deployments.simple_manifest
              stemcell = {
                'alias' => 'ubuntu',
                'os' => 'ubuntu',
                'version' => '1',
              }
              manifest['stemcells'] = [stemcell]
              job = manifest['jobs'].first
              job.delete('resource_pool')
              job['stemcell'] = stemcell['alias']
              job['vm_type'] = Bosh::Spec::Deployments.vm_type['name']
              job['azs'] = ['z1']
              manifest
            end

            it 'succeeds' do
              expect(DeploymentPlan::Steps::PackageCompileStep).to receive(:new) do |job, config, _, _|
                expect(job.first).to be_instance_of(DeploymentPlan::Job)
                expect(config).to be_instance_of(DeploymentPlan::CompilationConfig)
              end.and_return(package_compile_step)
              expect(package_compile_step).to receive(:perform).with no_args

              job.perform
            end
          end

          context 'and multiple stemcells match the requested stemcell' do
            before {
              Bosh::Director::Models::Stemcell.create(
                  name: 'z-name-stemcell',
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

            context 'when dealing with links' do
              let(:planner_factory) { instance_double(Bosh::Director::DeploymentPlan::PlannerFactory)}
              let(:planner) { instance_double(Bosh::Director::DeploymentPlan::Planner)}
              let(:deployment_job) { instance_double(DeploymentPlan::Job)}

              before {
                allow(DeploymentPlan::PlannerFactory).to receive(:create).and_return(planner_factory)
                allow(planner_factory).to receive(:create_from_model).and_return(planner)
                allow(planner).to receive(:model).and_return(Bosh::Director::Models::Deployment.make(name: 'foo'))
                allow(planner).to receive(:release)
                allow(planner).to receive(:add_job)
                allow(planner).to receive(:compile_packages)
                allow(job).to receive(:create_job_with_all_the_templates_so_everything_compiles)
              }

              it 'skips links binding' do
                expect(planner).to receive(:bind_models).with(true)
                job.perform
              end
            end

            it 'chooses the first stemcell alphabetically by name' do
              job.perform
              expect(log_string).to match /Will compile with stemcell: ubuntu-stemcell/
            end
          end
        end
      end

      context 'when creating a tarball' do
        let(:blobstore_client) { instance_double('Bosh::Blobstore::BaseClient') }
        let(:archiver) { instance_double('Bosh::Director::Core::TarGzipper') }
        let(:package_compile_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep)}
        let(:planner) { instance_double(Bosh::Director::DeploymentPlan::Planner)}
        let(:task_dir) { Dir.mktmpdir }

        before {
          release = Bosh::Director::Models::Release.create(name: release_name)
          release_version = release.add_version(:version => '0.1-dev')
          release_version.add_package(Bosh::Director::Models::Package.make(name: 'foo'))
          release_version.add_package(Bosh::Director::Models::Package.make(name: 'bar'))
          release_version.add_template(
            :name => deployment_manifest['jobs'].first['templates'].first['name'],
            :version => 'foo_version',
            :release_id => release.id,
            fingerprint: 'foo_fingerprint',
            :blobstore_id => 'foo_blobstore_id',
            :sha1 => 'foo_sha1',
            :package_names_json => '["foo", "bar"]')

          stemcell = create_stemcell

          package_ruby = release_version.add_package(
              name: 'ruby',
              version: 'ruby_version',
              fingerprint: 'ruby_fingerprint',
              release_id: release.id,
              blobstore_id: 'ruby_package_blobstore_id',
              sha1: 'ruby_package_sha1',
              dependency_set_json: [].to_json,
          )
          package_ruby.add_compiled_package(
              sha1: 'ruby_compiled_package_sha1',
              blobstore_id: 'ruby_compiled_package_blobstore_id',
              dependency_key: [].to_json,
              build: 23,
              stemcell_os: 'ubuntu',
              stemcell_version: '1'
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
              dependency_key: '[["ruby","ruby_version"]]',
              build: 23,
              stemcell_os: 'ubuntu',
              stemcell_version: '1'
          )

          result_file = double('result file')
          allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)
          allow(Bosh::Director::Core::TarGzipper).to receive(:new).and_return(archiver)
          allow(Config).to receive(:event_log).and_return(EventLog::Log.new)
          allow(planner).to receive(:jobs) { ['fake-job'] }
          allow(planner).to receive(:compilation) { 'fake-compilation-config' }
          allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:new).and_return(package_compile_step)
          allow(package_compile_step).to receive(:perform).with no_args
          allow(job).to receive(:result_file).and_return(result_file)
          allow(result_file).to receive(:write)
        }

        it 'should order the files in the tarball' do
          allow(blobstore_client).to receive(:get)
          allow(blobstore_client).to receive(:create)
          expect(archiver).to receive(:compress) { |download_dir, sources, output_path|
            expect(sources).to eq(['./release.MF', './jobs', './compiled_packages'])
            File.write(output_path, 'Some glorious content')
          }
          job.perform
        end

        it 'should contain all compiled packages & jobs' do
          allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
              files = Dir.entries(download_dir)
              expect(files).to include('compiled_packages', 'release.MF', 'jobs')

              files = Dir.entries(File.join(download_dir, 'compiled_packages'))
              expect(files).to include('postgres.tgz')

              files = Dir.entries(File.join(download_dir, 'jobs'))
              expect(files).to include('foobar.tgz')

              File.write(output_path, 'Some glorious content')
          }

          expect(blobstore_client).to receive(:create)
          expect(blobstore_client).to receive(:get).with('ruby_compiled_package_blobstore_id', anything, sha1: 'ruby_compiled_package_sha1')
          expect(blobstore_client).to receive(:get).with('postgres_package_blobstore_id', anything, sha1: 'postgres_compiled_package_sha1')
          expect(blobstore_client).to receive(:get).with('foo_blobstore_id', anything, sha1: 'foo_sha1')
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
  stemcell: ubuntu/1
  dependencies: []
- name: postgres
  version: postgres_version
  fingerprint: postgres_fingerprint
  sha1: postgres_compiled_package_sha1
  stemcell: ubuntu/1
  dependencies:
  - ruby
jobs:
- name: foobar
  version: foo_version
  fingerprint: foo_fingerprint
  sha1: foo_sha1
commit_hash: unknown
uncommitted_changes: false
name: bosh-release
version: 0.1-dev
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
