require 'spec_helper'
require 'fileutils'

describe 'compiled releases', type: :integration do
  with_reset_sandbox_before_each

  context 'when only selected jobs are compiled' do
    context 'when only the compiled job is referenced in the deployment' do
      let(:manifest_hash) do
        {
          'name' => 'minimal',

          'releases' => [{
            'name' => 'test_release',
            'version' => 'latest',
          }],

          'update' => {
            'canaries' => 2,
            'canary_watch_time' => 4000,
            'max_in_flight' => 1,
            'update_watch_time' => 20,
          },
          'stemcells' => [{
            'alias' => 'default',
            'os' => 'centos-7',
            'version' => 'latest',
          }],
        }
      end
      let(:deployment_name) { manifest_hash['name'] }
      let(:cloud_config) { SharedSupport::DeploymentManifestHelper.simple_cloud_config }

      before do
        compiled_job_pkg1 = 'compiled_releases/test_release-4+dev.1-centos-7-3001-job_using_pkg_1-20181224-150940-167574.tgz'
        compiled_job_pkg23 = 'compiled_releases/test_release-4+dev.1-centos-7-3002-job_using_pkg_2_3-20181227-113108-45819.tgz'

        upload_cloud_config(cloud_config_hash: cloud_config)
        bosh_runner.run("upload-stemcell #{asset_path('light-bosh-stemcell-3002-aws-xen-centos-7-go_agent.tgz')}")

        bosh_runner.run("upload-release #{asset_path(compiled_job_pkg1)}")
        bosh_runner.run("upload-release #{asset_path(compiled_job_pkg23)}")

        manifest_hash['instance_groups'] = [
          SharedSupport::DeploymentManifestHelper.simple_instance_group(
            jobs: [
              { 'name' => 'job_using_pkg_2', 'release' => 'test_release' },
            ],
            instances: 1,
            stemcell: 'default',
          ),
        ]
      end
      it 'should not error' do
        out = deploy(manifest_hash: manifest_hash)

        expect(out).to_not include('Compiling packages: pkg_1/b0fe23fce97e2dc8fd9da1035dc637ecd8fc0a0f')
        expect(out).to_not include('Compiling packages: pkg_2/')
        expect(out).to_not include('Compiling packages: pkg_3_depends_on_2/')
      end
    end
  end

  context 'release and stemcell have been uploaded' do
    before do
      bosh_runner.run("upload-stemcell #{asset_path('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload-release #{asset_path('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
    end

    context 'it uploads the compiled release when there is no corresponding stemcell' do
      it 'should not raise an error' do
        bosh_runner.run('delete-stemcell bosh-aws-xen-hvm-centos-7-go_agent/3001')
        bosh_runner.run('delete-release test_release')
        expect do
          bosh_runner.run(
            "upload-release #{asset_path('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}",
          )
        end.to_not raise_exception
        output = bosh_runner.run('inspect-release test_release/1', json: true)
        expect(table(output)).to include(
          'package' => 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f',
          'blobstore_id' => /[a-f0-9\-]{36}/,
          'digest' => '735987b52907d970106f38413825773eec7cc577',
          'compiled_for' => 'centos-7/3001',
        )
        expect(table(output)).to include(
          'package' => 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f',
          'blobstore_id' => '',
          'digest' => '',
          'compiled_for' => '(source)',
        )
      end
    end

    context 'when older compiled and newer non-compiled (source release) versions of the same release are uploaded' do
      before do
        upload_cloud_config
      end

      context 'and they contain identical packages' do
        let(:manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.test_deployment_manifest_with_job('job_using_pkg_5', 'test_release')
          manifest['stemcells'].first.delete('os')
          manifest['stemcells'].first['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
          manifest['stemcells'].first['version'] = '3001'
          manifest['releases'][0]['version'] = '4'
          manifest
        end

        before do
          release_path = asset_path('compiled_releases/test_release/releases/test_release/test_release-4-same-packages-as-1.tgz')
          bosh_runner.run("upload-release #{release_path}")
        end

        it 'does not compile any packages' do
          output = deploy(manifest_hash: manifest)

          expect(output).to_not include('Started compiling packages')
        end
      end

      context 'and they contain one different package' do
        let(:manifest) do
          manifest = SharedSupport::DeploymentManifestHelper.test_deployment_manifest_with_job('job_using_pkg_5', 'test_release')
          manifest['stemcells'].first.delete('os')
          manifest['stemcells'].first['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
          manifest['stemcells'].first['version'] = '3001'
          manifest['releases'][0]['version'] = '3'
          manifest
        end

        before do
          release_path = asset_path('compiled_releases/test_release/releases/test_release/test_release-3-pkg1-updated.tgz')
          bosh_runner.run("upload-release #{release_path}")
        end

        it 'compiles only the package with the different version and those that depend on it' do
          out = deploy(manifest_hash: manifest)
          expect(out).to include('Compiling packages: pkg_1/b0fe23fce97e2dc8fd9da1035dc637ecd8fc0a0f')
          expect(out).to include('Compiling packages: pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')

          expect(out).to_not include('Compiling packages: pkg_2/')
          expect(out).to_not include('Compiling packages: pkg_3_depends_on_2/')
          expect(out).to_not include('Compiling packages: pkg_4_depends_on_3/')
        end
      end

      context 'when deploying with a stemcell that does not match the compiled release' do
        before do
          # switch deployment to use "ubuntu-stemcell/1"
          bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")
          upload_cloud_config
        end

        it 'fails with an error message saying there is no way to compile for that stemcell' do
          out = deploy(
            manifest_hash: SharedSupport::DeploymentManifestHelper.test_deployment_manifest_with_job('job_using_pkg_5', 'test_release'),
            failure_expected: true,
          )
          expect(out).to include('Error:')

          expect(out).to include <<~OUTPUT.strip
            Can't use release 'test_release/1'. It references packages without source code and are not compiled against stemcell 'ubuntu-stemcell/1':
             - 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f'
             - 'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154'
             - 'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c'
             - 'pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4'
             - 'pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4'
          OUTPUT
        end

        context 'and multiple releases are referenced in the current deployment' do
          before do
            release_path = asset_path('compiled_releases/release-test_release_a-1-on-centos-7-stemcell-3001.tgz')
            bosh_runner.run("upload-release #{release_path}")
          end

          it 'fails with an error message saying there is no way to compile the releases for that stemcell' do
            out = deploy(
              manifest_hash: SharedSupport::DeploymentManifestHelper.test_deployment_manifest_referencing_multiple_releases,
              failure_expected: true,
            )
            expect(out).to include('Error:')

            expect(out).to include <<~OUTPUT.strip
              Can't use release 'test_release/1'. It references packages without source code and are not compiled against stemcell 'ubuntu-stemcell/1':
               - 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f'
               - 'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154'
            OUTPUT

            expect(out).to include <<~OUTPUT.strip
              Can't use release 'test_release_a/1'. It references packages without source code and are not compiled against stemcell 'ubuntu-stemcell/1':
               - 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f'
               - 'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154'
               - 'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c'
               - 'pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4'
               - 'pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4'
            OUTPUT
          end
        end
      end
    end
  end

  context 'it exercises the entire compiled release lifecycle' do
    let(:manifest) do
      SharedSupport::DeploymentManifestHelper.manifest_with_release.merge(
        'instance_groups' => [
          {
            'name' => 'job_with_many_packages',
            'jobs' => [
              {
                'name' => 'job_with_many_packages',
                'release' => 'bosh-release',
              },
            ],
            'vm_type' => 'a',
            'instances' => 1,
            'networks' => [{ 'name' => 'a' }],
            'stemcell' => 'default',
          },
        ],
      )
    end

    it 'exports, deletes deployment & stemcell, uploads compiled, uploads patch-level stemcell, deploys' do
      upload_cloud_config

      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell.tgz')}")

      [
        'jobs/job_with_blocking_compilation',
        'packages/blocking_package',
        'jobs/fails_with_too_much_output',
        'packages/fails_with_too_much_output',
      ].each do |release_path|
        FileUtils.rm_rf(File.join(ClientSandbox.test_release_dir, release_path))
      end

      create_and_upload_test_release(force: true)

      manifest['stemcells'].first['version'] = 'latest'
      deploy(manifest_hash: manifest)

      bosh_runner.run('export-release -d simple bosh-release/0.1-dev toronto-os/1')

      bosh_runner.run('delete-deployment -d simple')
      bosh_runner.run('delete-release bosh-release')
      bosh_runner.run('delete-stemcell ubuntu-stemcell/1')

      release_path = ClientSandbox.bosh_work_dir
      bosh_runner.run("upload-release #{release_path}/bosh-release-0.1-dev-toronto-os-1-*.tgz")
      bosh_runner.run("upload-stemcell #{asset_path('valid_stemcell_1_1.tgz')}")

      create_call_count = current_sandbox.cpi.invocations_for_method('create_vm').size
      deploy(manifest_hash: manifest)
      expect(current_sandbox.cpi.invocations_for_method('create_vm').size).to eq(create_call_count + 1)
    end
  end
end
