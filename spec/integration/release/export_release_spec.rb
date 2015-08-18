require 'spec_helper'

describe 'export release', type: :integration do
  with_reset_sandbox_before_each

  context 'with a classic manifest' do
    before{
      target_and_login

      bosh_runner.run("upload release #{spec_asset('test_release.tgz')}")
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      set_deployment({manifest_hash: Bosh::Spec::Deployments.minimal_legacy_manifest})
      deploy({})
    }

    it 'compiles all packages of the release against the requested stemcell with classic manifest' do
      out = bosh_runner.run("export release test_release/1 toronto-os/1")
      expect(out).to match /Started compiling packages/
      expect(out).to match /Started compiling packages > pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154. Done/
      expect(out).to match /Started compiling packages > pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f. Done/
      expect(out).to match /Task ([0-9]+) done/
    end
  end

  context 'with no source packages and no compiled packages against the targeted stemcell' do
    before {
      target_and_login

      cloud_config_with_centos = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_with_centos['resource_pools'][0]['stemcell']['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
      cloud_config_with_centos['resource_pools'][0]['stemcell']['version'] = '3001'
      upload_cloud_config(:cloud_config_hash => cloud_config_with_centos)
    }

    it 'should raise an error' do
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")

      set_deployment({manifest_hash: Bosh::Spec::Deployments.test_deployment_manifest_with_job('job_using_pkg_5')})
      deploy({})

      out =  bosh_runner.run("export release test_release/1 toronto-os/1", failure_expected: true)
      expect(out).to include(<<-EOF)
Error 60001: Can't export release `test_release/1'. It references packages without source code that are not compiled against `ubuntu-stemcell/1':
 - pkg_1/16b4c8ef1574b3f98303307caad40227c208371f
 - pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154
 - pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c
 - pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4
 - pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4
      EOF
    end
  end

  context 'when there are two versions of the same release uploaded' do
    before {
      target_and_login

      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")

      cloud_config_with_centos = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_with_centos['resource_pools'][0]['stemcell']['name'] = 'bosh-aws-xen-hvm-centos-7-go_agent'
      cloud_config_with_centos['resource_pools'][0]['stemcell']['version'] = '3001'
      upload_cloud_config(:cloud_config_hash => cloud_config_with_centos)

      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-2-pkg2-updated.tgz')}")
    }

    it 'compiles the packages of the newer release when requested' do
      deployment_manifest = Bosh::Spec::Deployments.test_deployment_manifest
      deployment_manifest['releases'][0]['version'] = '2'
      set_deployment({ manifest_hash: deployment_manifest })
      deploy({})
      out = bosh_runner.run("export release test_release/2 centos-7/3001")
      expect(out).to include('Started compiling packages > pkg_2/e7f5b11c43476d74b2d12129b93cba584943e8d3')
      expect(out).to include('Started compiling packages > pkg_1/16b4c8ef1574b3f98303307caad40227c208371f')
      expect(out).to include('Started compiling packages > pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c')
      expect(out).to include('Started compiling packages > pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4')
      expect(out).to include('Started compiling packages > pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')
    end

    it 'compiles the packages of the older release when requested' do
      deployment_manifest = Bosh::Spec::Deployments.test_deployment_manifest
      set_deployment({ manifest_hash: deployment_manifest })
      deploy({})
      out = bosh_runner.run("export release test_release/1 centos-7/3001")
      expect(out).to include('Started compiling packages > pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154')
      expect(out).to include('Started compiling packages > pkg_1/16b4c8ef1574b3f98303307caad40227c208371f')
      expect(out).to include('Started compiling packages > pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c')
      expect(out).to include('Started compiling packages > pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4')
      expect(out).to include('Started compiling packages > pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')
    end

    it 'does not recompile packages unless they changed since last export' do
      deployment_manifest = Bosh::Spec::Deployments.test_deployment_manifest
      set_deployment({ manifest_hash: deployment_manifest })
      deploy({})
      bosh_runner.run("export release test_release/1 centos-7/3001")

      deployment_manifest['releases'][0]['version'] = '2'
      set_deployment({ manifest_hash: deployment_manifest })
      deploy({})
      out = bosh_runner.run("export release test_release/2 centos-7/3001")

      expect(out).to_not include('Started compiling packages > pkg_1/')
      expect(out).to include('Started compiling packages > pkg_2/e7f5b11c43476d74b2d12129b93cba584943e8d3')
      expect(out).to include('Started compiling packages > pkg_3_depends_on_2/413e3e9177f0037b1882d19fb6b377b5b715be1c')
      expect(out).to include('Started compiling packages > pkg_4_depends_on_3/9207b8a277403477e50cfae52009b31c840c49d4')
      expect(out).to include('Started compiling packages > pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')
    end

    it 'respects transitive dependencies when recompiling packages' do
      deployment_manifest = Bosh::Spec::Deployments.test_deployment_manifest
      set_deployment({ manifest_hash: deployment_manifest })
      deploy({})
      bosh_runner.run("export release test_release/1 centos-7/3001")

      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-3-pkg1-updated.tgz')}")
      deployment_manifest['releases'][0]['version'] = '3'
      set_deployment({ manifest_hash: deployment_manifest })
      deploy({})
      out = bosh_runner.run("export release test_release/3 centos-7/3001")

      expect(out).to include('Started compiling packages > pkg_1/b0fe23fce97e2dc8fd9da1035dc637ecd8fc0a0f')
      expect(out).to include('Started compiling packages > pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4')

      expect(out).to_not include('Started compiling packages > pkg_2/')
      expect(out).to_not include('Started compiling packages > pkg_3_depends_on_2/')
      expect(out).to_not include('Started compiling packages > pkg_4_depends_on_3/')
    end
  end

  context 'with a cloud config manifest' do
    before{
      target_and_login
      upload_cloud_config

      bosh_runner.run("upload release #{spec_asset('test_release.tgz')}")
      bosh_runner.run("upload release #{spec_asset('test_release_2.tgz')}")
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell_2.tgz')}")
      set_deployment({manifest_hash: Bosh::Spec::Deployments.multiple_release_manifest})
      deploy({})
    }

    it 'compiles all packages of the release against the requested stemcell with cloud config' do
      out = bosh_runner.run("export release test_release/1 toronto-os/1")
      expect(out).to match /Started compiling packages/
      expect(out).to match /Started compiling packages > pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154. Done/
      expect(out).to match /Started compiling packages > pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f. Done/
      expect(out).to match /Task ([0-9]+) done/
    end

    it 'does not compile packages that were already compiled' do
      bosh_runner.run("export release test_release/1 toronto-os/1")
      out = bosh_runner.run("export release test_release/1 toronto-os/1")
      expect(out).to_not match /Started compiling packages/
      expect(out).to_not match /Started compiling packages > pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154. Done/
      expect(out).to_not match /Started compiling packages > pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f. Done/
      expect(out).to match /Task ([0-9]+) done/
    end

    it 'compiles any release that is in the targeted deployment' do
      out = bosh_runner.run("export release test_release_2/2 toronto-os/1")
      expect(out).to match /Started compiling packages/
      expect(out).to match /Started compiling packages > pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154. Done/
      expect(out).to match /Started compiling packages > pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f. Done/
      expect(out).to match /Task ([0-9]+) done/
    end

    it 'compiles against a stemcell that is not in the resource pool of the targeted deployment' do
      out = bosh_runner.run("export release test_release/1 toronto-centos/2")

      expect(out).to match /Started compiling packages/
      expect(out).to match /Started compiling packages > pkg_2\/f5c1c303c2308404983cf1e7566ddc0a22a22154. Done/
      expect(out).to match /Started compiling packages > pkg_1\/16b4c8ef1574b3f98303307caad40227c208371f. Done/
      expect(out).to match /Task ([0-9]+) done/
    end

    it 'returns an error when the release does not exist' do
      expect {
        bosh_runner.run("export release app/1 toronto-os/1")
      }.to raise_error(RuntimeError, /Error 30005: Release `app' doesn't exist/)
    end

    it 'returns an error when the release version does not exist' do
      expect {
        bosh_runner.run("export release test_release/0.1 toronto-os/1")
      }.to raise_error(RuntimeError, /Error 30006: Release version `test_release\/0.1' doesn't exist/)
    end

    it 'returns an error when the stemcell os and version does not exist' do
      expect {
        bosh_runner.run("export release test_release/1 nonexistos/1")
      }.to raise_error(RuntimeError, /Error 50003: Stemcell version `1' for OS `nonexistos' doesn't exist/)
    end

    it 'raises an error when exporting a release version not matching the manifest release version' do
      bosh_runner.run("upload release #{spec_asset('valid_release.tgz')}")
      expect {
        bosh_runner.run("export release appcloud/0.1 toronto-os/1")
      }.to raise_error(RuntimeError, /Error 30011: Release version `appcloud\/0.1' not found in deployment `minimal' manifest/)
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

      out = bosh_runner.run("export release test_release/1 toronto-os/1")
      task_id = out[/\d+/].to_i

      result_file = File.open(current_sandbox.sandbox_path("boshdir/tasks/#{task_id}/result"), "r")
      tarball_data = Yajl::Parser.parse(result_file.read)

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

      out = bosh_runner.run("export release test_release/1 toronto-os/1")
      expect(out).to match /release-test_release-1-on-toronto-os-stem... downloading.../
      expect(out).to match /release-test_release-1-on-toronto-os-stem... downloaded/

      dir = File.join(Bosh::Dev::Sandbox::Workspace.dir, "client-sandbox", "bosh_work_dir")
      files = Dir.entries(dir)
      expect(files).to include("release-test_release-1-on-toronto-os-stemcell-1.tgz")

      Dir.mktmpdir do |temp_dir|
        tarball_path = File.join(dir, "release-test_release-1-on-toronto-os-stemcell-1.tgz")
        `tar xzf #{tarball_path} -C #{temp_dir}`
        files = Dir.entries(temp_dir)
        expect(files).to include("compiled_packages","release.MF","jobs")
      end
    end

    it 'logs the packages and jobs names and versions while copying them' do
      out = bosh_runner.run("export release test_release/1 toronto-os/1")

      expect(out).to include('Started copying packages')
      expect(out).to include('Started copying packages > pkg_2/f5c1c303c2308404983cf1e7566ddc0a22a22154. Done')
      expect(out).to include('Started copying packages > pkg_1/16b4c8ef1574b3f98303307caad40227c208371f. Done')
      expect(out).to include('Done copying packages')

      expect(out).to include('Started copying jobs')
      expect(out).to include('Started copying jobs > job_using_pkg_1/9a5f09364b2cdc18a45172c15dca21922b3ff196. Done')
      expect(out).to include('Started copying jobs > job_using_pkg_1_and_2/673c3689362f2adb37baed3d8d4344cf03ff7637. Done')
      expect(out).to include('Started copying jobs > job_using_pkg_2/8e9e3b5aebc7f15d661280545e9d1c1c7d19de74. Done')
      expect(out).to include('Done copying jobs')
    end

    it 'logs the full release.MF in the director debug log' do
      export_release_output = bosh_runner.run("export release test_release/1 toronto-os/1")
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

  end
  context 'when there is an existing deployment with running VMs' do
    before {
      target_and_login
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      upload_cloud_config(:cloud_config_hash => Bosh::Spec::Deployments.simple_cloud_config)
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
      set_deployment({manifest_hash: Bosh::Spec::Deployments.test_deployment_manifest_with_job('job_using_pkg_5')})
      deploy({})
    }

    it 'allocates non-conflicting IPs for compilation VMs' do
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      output =  bosh_runner.run("export release test_release/1 centos-7/3001")
      expect(output).to include('Done compiling packages')
      expect(output).to include('Done copying packages')
      expect(output).to include('Done copying jobs')
      expect(output).to include("Exported release `test_release/1` for `centos-7/3001`")
    end
  end
end
