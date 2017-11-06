require_relative '../../spec_helper'

describe 'export-release', type: :integration do
  with_reset_sandbox_before_each

  context 'with a classic manifest' do
    before{
      bosh_runner.run("upload-release #{spec_asset('test_release.tgz')}")
      bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
      deploy_simple_manifest({manifest_hash: Bosh::Spec::Deployments.minimal_legacy_manifest})
    }

    it 'compiles all packages of the release against the requested stemcell with classic manifest' do
      out = bosh_runner.run('export-release test_release/1 toronto-os/1', deployment_name: 'minimal_legacy_manifest')
      expect(out).to match(/Compiling packages/)
      expect(out).to match(/Compiling packages: pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154 \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Compiling packages: pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Task ([0-9]+) done/)
    end
  end

  context 'with no source packages and no compiled packages against the targeted stemcell' do
    it 'should raise an error' do
      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("upload-stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")

      manifest = Bosh::Spec::NewDeployments.test_deployment_manifest_with_job('job_using_pkg_5')
      manifest['stemcells'] = [{'name' => 'bosh-aws-xen-hvm-centos-7-go_agent', 'alias' => 'default', 'version' => '3001'}]
      deploy_simple_manifest(manifest_hash: manifest)

      out = bosh_runner.run('export-release test_release/1 toronto-os/1', failure_expected: true, deployment_name: 'test_deployment')
      expect(out).to include(<<-EOF)
Can't use release 'test_release/1'. It references packages without source code and are not compiled against stemcell 'ubuntu-stemcell/1':
 - 'pkg_1/16b4c8ef1574b3f98303307caad40227c208371f'
 - 'pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154'
 - 'pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c'
 - 'pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4'
 - 'pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4'
      EOF
    end
  end

  context 'when there are two versions of the same release uploaded' do
    let(:deployment_manifest) { Bosh::Spec::NewDeployments.test_deployment_manifest }

    before do
      bosh_runner.run("upload-stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")

      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      deployment_manifest['stemcells'].first['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
      deployment_manifest['stemcells'].first['version'] = '3001'
      deployment_manifest['stemcells'].first.delete('os')

      bosh_runner.run("upload-release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-2-pkg2-updated.tgz')}")
    end

    it 'compiles the packages of the newer release when requested' do
      deployment_manifest['releases'][0]['version'] = '2'
      deploy_simple_manifest(manifest_hash: deployment_manifest)
      out = bosh_runner.run('export-release test_release/2 centos-7/3001', deployment_name: 'test_deployment')
      expect(out).to include('Compiling packages: pkg_2/e7f5b11c43476d74b2d12129b93cba584943e8d3')
      expect(out).to include('Compiling packages: pkg_1/16b4c8ef1574b3f98303307caad40227c208371f')
      expect(out).to include('Compiling packages: pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c')
      expect(out).to include('Compiling packages: pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4')
      expect(out).to include('Compiling packages: pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')
    end

    it 'compiles the packages of the older release when requested' do
      deploy_simple_manifest(manifest_hash: deployment_manifest)
      out = bosh_runner.run('export-release test_release/1 centos-7/3001', deployment_name: 'test_deployment')
      expect(out).to include('Compiling packages: pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154')
      expect(out).to include('Compiling packages: pkg_1/16b4c8ef1574b3f98303307caad40227c208371f')
      expect(out).to include('Compiling packages: pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c')
      expect(out).to include('Compiling packages: pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4')
      expect(out).to include('Compiling packages: pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')
    end

    it 'does not recompile packages unless they changed since last export' do
      deploy_simple_manifest(manifest_hash: deployment_manifest)
      bosh_runner.run('export-release test_release/1 centos-7/3001', deployment_name: 'test_deployment')

      deployment_manifest['releases'][0]['version'] = '2'
      deploy_simple_manifest(manifest_hash: deployment_manifest)
      out = bosh_runner.run('export-release test_release/2 centos-7/3001', deployment_name: 'test_deployment')

      expect(out).to_not include('Compiling packages: pkg_1/')
      expect(out).to include('Compiling packages: pkg_2/e7f5b11c43476d74b2d12129b93cba584943e8d3')
      expect(out).to include('Compiling packages: pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c')
      expect(out).to include('Compiling packages: pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4')
      expect(out).to include('Compiling packages: pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')
    end

    it 'respects transitive dependencies when recompiling packages' do
      deploy_simple_manifest(manifest_hash: deployment_manifest)
      bosh_runner.run('export-release test_release/1 centos-7/3001', deployment_name: 'test_deployment')

      bosh_runner.run("upload-release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-3-pkg1-updated.tgz')}")
      deployment_manifest['releases'][0]['version'] = '3'
      deploy_simple_manifest(manifest_hash: deployment_manifest)
      out = bosh_runner.run('export-release test_release/3 centos-7/3001', deployment_name: 'test_deployment')

      expect(out).to include('Compiling packages: pkg_1/b0fe23fce97e2dc8fd9da1035dc637ecd8fc0a0f')
      expect(out).to include('Compiling packages: pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')

      expect(out).to_not include('Compiling packages: pkg_2/')
      expect(out).to_not include('Compiling packages: pkg_3_depends_on_2/')
      expect(out).to_not include('Compiling packages: pkg_4_depends_on_3/')
    end
  end

  context 'with a cloud config manifest' do
    let(:cloud_config) { Bosh::Spec::NewDeployments.simple_cloud_config }
    let(:manifest_hash) { Bosh::Spec::NewDeployments.multiple_release_manifest }

    before{
      upload_cloud_config(cloud_config_hash: cloud_config)

      bosh_runner.run("upload-release #{spec_asset('test_release.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('test_release_2.tgz')}")
      bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell_2.tgz')}")
      deploy_simple_manifest(manifest_hash: manifest_hash)
    }

    context 'when using vm_types and stemcells and networks with azs' do
      let(:cloud_config) do
        config = Bosh::Spec::NewDeployments.simple_cloud_config
        config['azs'] = [{'name' => 'z1', 'cloud_properties' => {}}]
        config['networks'].first['subnets'].first['az'] = 'z1'
        config['compilation']['az'] = 'z1'
        config
      end

      it 'compiles all packages of the release against the requested stemcell' do
        out = bosh_runner.run('export-release test_release/1 toronto-os/1', deployment_name: 'minimal')
        expect(out).to match(/Compiling packages/)
        expect(out).to match(/Compiling packages: pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154 \(\d{2}:\d{2}:\d{2}\)/)
        expect(out).to match(/Compiling packages: pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f \(\d{2}:\d{2}:\d{2}\)/)
        expect(out).to match(/Task ([0-9]+) done/)
      end
    end

    it 'compiles all packages of the release against the requested stemcell with cloud config' do
      out = bosh_runner.run('export-release test_release/1 toronto-os/1', deployment_name: 'minimal')
      expect(out).to match(/Compiling packages/)
      expect(out).to match(/Compiling packages: pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154 \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Compiling packages: pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Task ([0-9]+) done/)
    end

    it 'does not compile packages that were already compiled' do
      bosh_runner.run('export-release test_release/1 toronto-os/1', deployment_name: 'minimal')
      out = bosh_runner.run('export-release test_release/1 toronto-os/1', deployment_name: 'minimal')
      expect(out).to_not match(/Compiling packages/)
      expect(out).to_not match(/Compiling packages: pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154 \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to_not match(/Compiling packages: pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Task ([0-9]+) done/)
    end

    it 'compiles any release that is in the targeted deployment' do
      out = bosh_runner.run('export-release test_release_2/2 toronto-os/1', deployment_name: 'minimal')
      expect(out).to match(/Compiling packages/)
      expect(out).to match(/Compiling packages: pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154 \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Compiling packages: pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Task ([0-9]+) done/)
    end

    it 'compiles against a stemcell that is not in the resource pool of the targeted deployment' do
      out = bosh_runner.run('export-release test_release/1 toronto-centos/2', deployment_name: 'minimal')

      expect(out).to match(/Compiling packages/)
      expect(out).to match(/Compiling packages: pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154 \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Compiling packages: pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/Task ([0-9]+) done/)
    end

    it 'returns an error when the release does not exist' do
      expect {
        bosh_runner.run('export-release app/1 toronto-os/1', deployment_name: 'minimal')
      }.to raise_error(RuntimeError, /Error: Release 'app' doesn't exist/)
    end

    it 'returns an error when the release version does not exist' do
      expect {
        bosh_runner.run('export-release test_release/0.1 toronto-os/1', deployment_name: 'minimal')
      }.to raise_error(RuntimeError, /Error: Release version 'test_release\/0.1' doesn't exist/)
    end

    it 'returns an error when the stemcell os and version does not exist' do
      expect {
        bosh_runner.run('export-release test_release/1 nonexistos/1', deployment_name: 'minimal')
      }.to raise_error(RuntimeError, /Error: Stemcell version '1' for OS 'nonexistos' doesn't exist/)
    end

    it 'raises an error when exporting a release version not matching the manifest release version' do
      bosh_runner.run("upload-release #{spec_asset('valid_release.tgz')}")
      expect {
        bosh_runner.run('export-release appcloud/0.1 toronto-os/1', deployment_name: 'minimal')
      }.to raise_error(RuntimeError, /Error: Release version 'appcloud\/0.1' not found in deployment 'minimal' manifest/)
    end

    it 'puts a tarball in the blobstore' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        File.open('config/final.yml', 'w') do |final|
          final.puts YAML.dump(
                         'blobstore' => {
                             'provider' => 'local',
                             'options' => { 'blobstore_path' => current_sandbox.blobstore_storage_dir },
                         },
                     )
        end
      end

      out = bosh_runner.run("export-release test_release/1 toronto-os/1", deployment_name: 'minimal')
      task_id = bosh_runner.get_most_recent_task_id

      result_data = bosh_runner.run("task #{task_id} --result")

      regex = /^{"blobstore_id".*$/
      tarball_data= JSON.parse(result_data.match(regex)[0])
      files = Dir.entries(current_sandbox.blobstore_storage_dir)
      expect(files).to include(tarball_data['blobstore_id'])

      Dir.mktmpdir do |temp_dir|
        tarball_path = File.join(current_sandbox.blobstore_storage_dir, tarball_data['blobstore_id'])
        `tar xzf #{tarball_path} -C #{temp_dir}`
        files = Dir.entries(temp_dir)
        expect(files).to include("compiled_packages","release.MF","jobs")
      end
    end

    it 'downloads a tarball from the blobstore to the current directory' do
      Dir.chdir(ClientSandbox.test_release_dir) do
        File.open('config/final.yml', 'w') do |final|
          final.puts YAML.dump(
                         'blobstore' => {
                             'provider' => 'local',
                             'options' => { 'blobstore_path' => current_sandbox.blobstore_storage_dir },
                         },
                     )
        end
      end

      out = bosh_runner.run("export-release test_release/1 toronto-os/1", deployment_name: 'minimal')
      expect(out).to match(/Downloading resource '[0-9a-f-]{36}' to '.*test_release-1-toronto-os-1-\d{8}-[0-9-]*\.tgz'.../)
      expect(out).to match(/Succeeded/)

      output_file = File.basename(out.match(/Downloading resource '[0-9a-f-]{36}' to '(.*test_release-1-toronto-os-1-\d{8}-[0-9-]*\.tgz)'.../)[1])

      dir = File.join(Bosh::Dev::Sandbox::Workspace.dir, "client-sandbox", "bosh_work_dir")
      files = Dir.entries(dir)
      expect(files).to include(output_file)

      Dir.mktmpdir do |temp_dir|
        tarball_path = File.join(dir, output_file)
        `tar xzf #{tarball_path} -C #{temp_dir}`
        files = Dir.entries(temp_dir)
        expect(files).to include("compiled_packages","release.MF","jobs")
      end
    end

    it 'logs the packages and jobs names and versions while copying them' do
      out = bosh_runner.run("export-release test_release/1 toronto-os/1", deployment_name: 'minimal')

      expect(out).to match(/copying packages: pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154 \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/copying packages: pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f \(\d{2}:\d{2}:\d{2}\)/)

      expect(out).to match(/copying jobs: job_using_pkg_1\/9a5f09364b2cdc18a45172c15dca21922b3ff196 \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/copying jobs: job_using_pkg_1_and_2\/673c3689362f2adb37baed3d8d4344cf03ff7637 \(\d{2}:\d{2}:\d{2}\)/)
      expect(out).to match(/copying jobs: job_using_pkg_2\/8e9e3b5aebc7f15d661280545e9d1c1c7d19de74 \(\d{2}:\d{2}:\d{2}\)/)
    end

    it 'logs the full release.MF in the director debug log' do
      export_release_output = bosh_runner.run("export-release test_release/1 toronto-os/1", deployment_name: 'minimal')
      task_number =  export_release_output[/Task \d+ done/][/\d+/]

      debug_task_output = bosh_runner.run("task #{task_number} --debug")

      expect(debug_task_output).to include('release.MF contents of test_release/1 compiled release tarball:')
      expect(debug_task_output).to include('name: test_release')
      expect(debug_task_output).to include('version: \'1\'')
      expect(debug_task_output).to include('- name: pkg_1')
      expect(debug_task_output).to include('- name: pkg_2')
      expect(debug_task_output).to include('- name: job_using_pkg_1')
      expect(debug_task_output).to include('- name: job_using_pkg_1_and_2')
      expect(debug_task_output).to include('- name: job_using_pkg_2')
    end

    context 'when specifying a job to export' do
      it 'exports only the selected job and its package dependencies' do
        export_release_output = bosh_runner.run("export-release test_release/1 toronto-os/1 --job job_using_pkg_1", deployment_name: 'minimal')
        output_file = File.basename(export_release_output.match(/Downloading resource '[0-9a-f-]{36}' to '(.*test_release-1-toronto-os-1-\d{8}-[0-9-]*\.tgz)'.../)[1])

        dir = File.join(Bosh::Dev::Sandbox::Workspace.dir, "client-sandbox", "bosh_work_dir")
        files = Dir.entries(dir)
        expect(files).to include(output_file)

        Dir.mktmpdir do |temp_dir|
          tarball_path = File.join(dir, output_file)
          `tar xzf #{tarball_path} -C #{temp_dir}`
          files = Dir.entries(temp_dir)
          expect(files).to include("compiled_packages","release.MF","jobs")
          release_manifest = YAML.load_file(File.join(temp_dir, "release.MF"))
          expect(release_manifest['compiled_packages'].map { |p| p['name'] }).to contain_exactly('pkg_1')
          expect(release_manifest['jobs'].map {|p| p['name']}).to contain_exactly('job_using_pkg_1')
        end
      end
    end
  end

  context 'when there is an existing deployment with running VMs' do
    context 'with global networking' do
      before do
        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
        upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
        bosh_runner.run("upload-release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")

        deployment_manifest = Bosh::Spec::NewDeployments.minimal_manifest_with_ubuntu_stemcell
        deployment_manifest['jobs'] = [{
            'name'          => 'job_using_pkg_5',
            'templates'     => [],
            'vm_type' => 'a',
            'instances'     => 0,
            'networks'      => [{ 'name' => 'a' }],
            'stemcell' => 'default'
          }]

        deploy_simple_manifest(manifest_hash: deployment_manifest)
      end

      it 'allocates non-conflicting IPs for compilation VMs' do
        bosh_runner.run("upload-stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
        output = bosh_runner.run('export-release test_release/1 centos-7/3001', deployment_name: 'minimal')
        expect(output).to include('Succeeded')
      end
    end

    context 'before global networking' do
      before do
        bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')}")
        bosh_runner.run("upload-release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
        legacy_manifest = Bosh::Spec::Deployments.simple_cloud_config.merge(
          Bosh::Spec::Deployments.test_deployment_manifest_with_job('job_using_pkg_5')
        )
        deploy_simple_manifest(manifest_hash: legacy_manifest)
      end

      it 'allocates non-conflicting IPs for compilation VMs' do
        bosh_runner.run("upload-stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
        output = bosh_runner.run('export-release test_release/1 centos-7/3001', deployment_name: 'test_deployment')
        expect(output).to include('Succeeded')
      end
    end
  end
end
