require 'rubygems'
require 'rubygems/package'
require 'spec_helper'

module Bosh::Director
  describe Jobs::ExportRelease do
    include Support::FakeLocks

    let(:multi_digest) { instance_double(Digest::MultiDigest) }
    let(:sha2) { nil }

    let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}
    let(:task_result) { Bosh::Director::TaskDBWriter.new(:result_output, task.id) }
    let(:package_compile_step) { instance_double(DeploymentPlan::Steps::PackageCompileStep)}

    let(:planner_model) { instance_double(Bosh::Director::Models::Deployment) }
    let(:assembler) { instance_double(DeploymentPlan::Assembler, bind_models: nil) }

    let(:options) { {} }

    before do
      fake_locks
      allow(Digest::MultiDigest).to receive(:new).and_return(multi_digest)
      Bosh::Director::Config.current_job = job
      Bosh::Director::Config.current_job.task_id = task.id
      allow(job).to receive(:task_cancelled?) { false }
      blobstore = double(:blobstore)
      blobstores = instance_double(Bosh::Director::Blobstores, blobstore: blobstore)
      app = instance_double(App, blobstores: blobstores)
      allow(App).to receive(:instance).and_return(app)
      allow(multi_digest).to receive(:create).and_return('expected-sha1')
      allow(Config).to receive(:result).and_return(task_result)
      allow(planner_model).to receive(:add_variable_set)

      allow(DeploymentPlan::Assembler).to receive(:create).and_return(assembler)
    end

    subject(:job) { described_class.new(deployment_manifest['name'], release_name, manifest_release_version, 'ubuntu', '1', sha2, options) }

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
    let(:deployment_manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

    it 'raises an error when the targeted deployment is not found' do
      create_stemcell
      expect {
        job.perform
      }.to raise_error(Bosh::Director::DeploymentNotFound)
    end

    context 'with a valid deployment targeted' do
      let(:cloud_config) { Bosh::Spec::NewDeployments.simple_cloud_config }

      let!(:deployment_model) do
        deployment = Models::Deployment.make(
          name: deployment_manifest['name'],
          manifest: YAML.dump(deployment_manifest),
        )
        deployment.cloud_configs = [Models::Config.make(:cloud, content: YAML.dump(cloud_config))]
        deployment
      end

      before do
        Models::VariableSet.create(deployment: deployment_model)

        allow(job).to receive(:with_deployment_lock).and_yield
      end

      it 'raises an error when the requested release does not exist' do
        create_stemcell
        expect {
          job.perform
        }.to raise_error(Bosh::Director::ReleaseNotFound)
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
            :name => deployment_manifest['instance_groups'].first['jobs'].first['name'],
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
          before do
            create_stemcell
            allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:create).and_return(package_compile_step)
            allow(job).to receive(:create_tarball)
            allow(package_compile_step).to receive(:perform)
          end

          it 'locks the deployment, release, and selected stemcell' do
            lock_timeout = {:timeout=>900} # 15 minutes. 15 * 60
            expect(job).to receive(:with_deployment_lock).with(deployment_manifest['name'], lock_timeout).and_yield

            job.perform
          end

          it 'succeeds' do
            expect(package_compile_step).to receive(:perform).with no_args

            job.perform
          end

          context 'when using vm_types, stemcells, and azs' do
            let(:cloud_config) do
              config = Bosh::Spec::NewDeployments.simple_cloud_config
              config['azs'] = [{'name' => 'z1', 'cloud_properties' => {}}]
              config['networks'].first['subnets'].first['az'] = 'z1'
              config['vm_types'] =  [Bosh::Spec::NewDeployments.vm_type]
              config['compilation']['az'] = 'z1'
              config
            end

            let(:deployment_manifest) do
              manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
              stemcell = {
                'alias' => 'ubuntu',
                'os' => 'ubuntu',
                'version' => '1',
              }
              manifest['stemcells'] = [stemcell]
              instance_group = manifest['instance_groups'].first
              instance_group['stemcell'] = stemcell['alias']
              instance_group['vm_type'] = Bosh::Spec::NewDeployments.vm_type['name']
              instance_group['azs'] = ['z1']
              manifest
            end

            it 'succeeds' do
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
              let(:deployment_job) { instance_double(DeploymentPlan::InstanceGroup)}

              before {
                allow(DeploymentPlan::PlannerFactory).to receive(:create).and_return(planner_factory)
                allow(planner_factory).to receive(:create_from_model).and_return(planner)
                allow(planner).to receive(:model).and_return(Bosh::Director::Models::Deployment.make(name: 'foo'))
                allow(planner).to receive(:release)
                allow(planner).to receive(:add_instance_group)
                allow(job).to receive(:create_compilation_instance_group)
              }

              it 'skips links binding' do
                expect(assembler).to receive(:bind_models).with({:should_bind_links => false, :should_bind_properties=>false})
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
        let(:planner_factory) { DeploymentPlan::PlannerFactory.create(logger) }
        let(:planner) { planner_factory.create_from_model(deployment_model) }
        let(:task_dir) { Dir.mktmpdir }
        let(:release) {Bosh::Director::Models::Release.create(name: release_name)}
        let(:release_version) {release.add_version(:version => '0.1-dev')}

        before do
          release_version.add_package(Bosh::Director::Models::Package.make(name: 'foo'))
          release_version.add_package(Bosh::Director::Models::Package.make(name: 'bar'))

          release_version.add_template(
            :name => deployment_manifest['instance_groups'].first['jobs'].first['name'],
            :version => 'foo_version',
            :release_id => release.id,
            fingerprint: 'foobar_fingerprint',
            :blobstore_id => 'foobar_blobstore_id',
            :sha1 => 'foo_sha1',
            :package_names_json => '["foo", "bar"]')

          release_version.add_template(
            :name => 'foobaz',
            :version => 'foo_version',
            :release_id => release.id,
            fingerprint: 'foobaz_fingerprint',
            :blobstore_id => 'foobaz_blobstore_id',
            :sha1 => 'foo_sha1',
            :package_names_json => '["foo", "bar"]')

          release_version.add_template(
            :name => 'foofoo',
            :version => 'foo_version',
            :release_id => release.id,
            fingerprint: 'foofoo_fingerprint',
            :blobstore_id => 'foofoo_blobstore_id',
            :sha1 => 'foo_sha1',
            :package_names_json => '["foo", "bar"]')

          create_stemcell

          package_ruby = release_version.add_package(
              name: 'ruby',
              version: 'ruby_version',
              fingerprint: 'ruby_fingerprint',
              release_id: release.id,
              blobstore_id: 'ruby_package_blobstore_id',
              sha1: 'rubypackagesha1',
              dependency_set_json: [].to_json,
          )
          package_ruby.add_compiled_package(
              sha1: 'rubycompiledpackagesha1',
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
              dependency_set_json: JSON.generate(["ruby"]),
          )
          package_postgres.add_compiled_package(
              sha1: 'postgrescompiledpackagesha1',
              blobstore_id: 'postgres_package_blobstore_id',
              dependency_key: '[["ruby","ruby_version"]]',
              build: 23,
              stemcell_os: 'ubuntu',
              stemcell_version: '1'
          )

          allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)
          allow(Bosh::Director::Core::TarGzipper).to receive(:new).and_return(archiver)
          allow(Config).to receive(:event_log).and_return(EventLog::Log.new)
          allow(DeploymentPlan::PlannerFactory).to receive(:create).and_return(planner_factory)
          allow(planner_factory).to receive(:create_from_model).and_return(planner)
          allow(DeploymentPlan::Steps::PackageCompileStep).to receive(:create).and_return(package_compile_step)
          allow(package_compile_step).to receive(:perform).with no_args
        end

        it 'should order the files in the tarball' do
          allow(blobstore_client).to receive(:get)
          allow(blobstore_client).to receive(:create).and_return('blobstore_id')
          expect(archiver).to receive(:compress) { |download_dir, sources, output_path|
            expect(sources).to eq(['./release.MF', './jobs', './compiled_packages'])
            File.write(output_path, 'Some glorious content')
          }
          job.perform
        end

        context 'when specific jobs are not specified' do
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

            expect(blobstore_client).to receive(:create).and_return('blobstore_id')
            expect(blobstore_client).to receive(:get).with('ruby_compiled_package_blobstore_id', anything, sha1: 'rubycompiledpackagesha1')
            expect(blobstore_client).to receive(:get).with('postgres_package_blobstore_id', anything, sha1: 'postgrescompiledpackagesha1')
            expect(blobstore_client).to receive(:get).with('foobar_blobstore_id', anything, sha1: 'foo_sha1')
            expect(blobstore_client).to receive(:get).with('foobaz_blobstore_id', anything, sha1: 'foo_sha1')
            expect(blobstore_client).to receive(:get).with('foofoo_blobstore_id', anything, sha1: 'foo_sha1')
            job.perform
          end

          it 'creates a manifest file that contains the sha1, fingerprint and blobstore_id' do
            allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
              manifest_hash = YAML.load_file(File.join(download_dir, 'release.MF'))
              expected_manifest_hash = YAML.load(%q(---
compiled_packages:
- name: postgres
  version: postgres_version
  fingerprint: postgres_fingerprint
  sha1: postgrescompiledpackagesha1
  stemcell: ubuntu/1
  dependencies:
  - ruby
- name: ruby
  version: ruby_version
  fingerprint: ruby_fingerprint
  sha1: rubycompiledpackagesha1
  stemcell: ubuntu/1
  dependencies: []
jobs:
- name: foobar
  version: foo_version
  fingerprint: foobar_fingerprint
  sha1: foo_sha1
- name: foobaz
  version: foo_version
  fingerprint: foobaz_fingerprint
  sha1: foo_sha1
- name: foofoo
  version: foo_version
  fingerprint: foofoo_fingerprint
  sha1: foo_sha1
commit_hash: unknown
uncommitted_changes: false
name: bosh-release
version: 0.1-dev
))

              File.write(output_path, 'Some glorious content')

              expect(manifest_hash['compiled_packages']).to match_array(expected_manifest_hash['compiled_packages'])
              expect(manifest_hash['jobs']).to match_array(expected_manifest_hash['jobs'])

              manifest_hash.delete('compiled_packages')
              expected_manifest_hash.delete('compiled_packages')
              manifest_hash.delete('jobs')
              expected_manifest_hash.delete('jobs')

              expect(manifest_hash).to eq(expected_manifest_hash)
            }

            allow(blobstore_client).to receive(:get)
            allow(blobstore_client).to receive(:create).and_return('blobstore_id')

            job.perform
          end
        end

        context 'when an empty list of jobs are specified' do
          let(:deployment_manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }
          let(:options) {
            {
              'jobs' => []
            }
          }

          it 'should contain all jobs' do
            allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
              files = Dir.entries(download_dir)
              expect(files).to include('compiled_packages', 'release.MF', 'jobs')

              files = Dir.entries(File.join(download_dir, 'compiled_packages'))
              expect(files).to include('postgres.tgz')

              files = Dir.entries(File.join(download_dir, 'jobs'))
              expect(files).to contain_exactly('.', '..', 'foobaz.tgz', 'foobar.tgz', 'foofoo.tgz')

              File.write(output_path, 'Some glorious content')
            }

            expect(blobstore_client).to receive(:create).and_return('blobstore_id')
            expect(blobstore_client).to receive(:get).with('ruby_compiled_package_blobstore_id', anything, sha1: 'rubycompiledpackagesha1')
            expect(blobstore_client).to receive(:get).with('postgres_package_blobstore_id', anything, sha1: 'postgrescompiledpackagesha1')
            allow(blobstore_client).to receive(:get)
            job.perform
          end
        end

        context 'when specific jobs are specified' do
          let(:deployment_manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

          let(:options) {
            {
              'jobs' => [{'name' => 'foobaz'}]
            }
          }

          it 'should contain only specified jobs' do
            allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
              files = Dir.entries(download_dir)
              expect(files).to include('compiled_packages', 'release.MF', 'jobs')

              files = Dir.entries(File.join(download_dir, 'compiled_packages'))
              expect(files).to include('postgres.tgz')

              files = Dir.entries(File.join(download_dir, 'jobs'))
              expect(files).to include('foobaz.tgz')
              expect(files).not_to include('foobar.tgz', 'foofoo.tgz')

              File.write(output_path, 'Some glorious content')
            }

            expect(blobstore_client).to receive(:create).and_return('blobstore_id')
            expect(blobstore_client).to receive(:get).with('ruby_compiled_package_blobstore_id', anything, sha1: 'rubycompiledpackagesha1')
            expect(blobstore_client).to receive(:get).with('postgres_package_blobstore_id', anything, sha1: 'postgrescompiledpackagesha1')
            allow(blobstore_client).to receive(:get)
            job.perform
          end

          it 'creates a manifest file that contains the sha1, fingerprint and blobstore_id' do
            allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
              manifest_hash = YAML.load_file(File.join(download_dir, 'release.MF'))
              expected_manifest_hash = YAML.load(%q(---
compiled_packages:
- name: postgres
  version: postgres_version
  fingerprint: postgres_fingerprint
  sha1: postgrescompiledpackagesha1
  stemcell: ubuntu/1
  dependencies:
  - ruby
- name: ruby
  version: ruby_version
  fingerprint: ruby_fingerprint
  sha1: rubycompiledpackagesha1
  stemcell: ubuntu/1
  dependencies: []
jobs:
- name: foobaz
  version: foo_version
  fingerprint: foobaz_fingerprint
  sha1: foo_sha1
commit_hash: unknown
uncommitted_changes: false
name: bosh-release
version: 0.1-dev
))

              File.write(output_path, 'Some glorious content')

              expect(manifest_hash['compiled_packages']).to match_array(expected_manifest_hash['compiled_packages'])
              expect(manifest_hash['jobs']).to match_array(expected_manifest_hash['jobs'])

              manifest_hash.delete('compiled_packages')
              expected_manifest_hash.delete('compiled_packages')
              manifest_hash.delete('jobs')
              expected_manifest_hash.delete('jobs')

              expect(manifest_hash).to eq(expected_manifest_hash)
            }

            allow(blobstore_client).to receive(:get)
            allow(blobstore_client).to receive(:create).and_return('blobstore_id')

            job.perform
          end
        end

        it 'should put a tarball in the blobstore' do
          allow(blobstore_client).to receive(:get)
          allow(blobstore_client).to receive(:create).and_return("77da2388-ecf7-4cf6-be52-b054a07ea307")
          allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
             File.write(output_path, 'Some glorious content')
           }

          job.perform
        end

        it 'should calculate the digest of the generated archive using the sha1 algorithm by default' do
          expected_blobstore_id = '77da2388-ecf7-4cf6-be52-b054a07ea307'

          allow(blobstore_client).to receive(:get)
          allow(blobstore_client).to receive(:create).and_return(expected_blobstore_id)
          allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
            File.write(output_path, 'Some glorious content')
            expect(multi_digest).to receive(:create).with(['sha1'], output_path).and_return('expected-sha1')
          }

          job.perform
        end

        context 'when the sha2 constructor arg is truthy' do
          let(:sha2) { "true" }
          it 'should calculate the digest of the generated archive using the sha256 algorithm when sha2' do
            expected_blobstore_id = '77da2388-ecf7-4cf6-be52-b054a07ea307'

            allow(blobstore_client).to receive(:get)
            allow(blobstore_client).to receive(:create).and_return(expected_blobstore_id)
            allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
              File.write(output_path, 'Some glorious content')
              expect(multi_digest).to receive(:create).with(['sha256'], output_path).and_return('expected-sha2')
            }

            job.perform
          end
        end

        context 'that is successfully placed in the blobstore' do
          it 'should record the blobstore id of the created tarball in the blobs table' do
            expected_blobstore_id = '77da2388-ecf7-4cf6-be52-b054a07ea307'

            allow(blobstore_client).to receive(:get)
            allow(blobstore_client).to receive(:create).and_return(expected_blobstore_id)
            allow(archiver).to receive(:compress) { |download_dir, sources, output_path|
              File.write(output_path, 'Some glorious content')
            }

            expect {
              job.perform
            }.to change(Bosh::Director::Models::Blob, :count).from(0).to(1)

            exported_release_blob = Bosh::Director::Models::Blob.first
            expect(exported_release_blob.blobstore_id).to eq(expected_blobstore_id)
            expect(exported_release_blob.sha1).to eq('expected-sha1')
            expect(exported_release_blob.type).to eq('exported-release')
          end
        end
      end
    end
  end
end
