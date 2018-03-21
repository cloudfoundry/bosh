require_relative '../spec_helper'

describe 'deploy job with addons', type: :integration do
  with_reset_sandbox_before_each

  context 'when runtime config' do
    it 'allows addons to be added to specific deployments' do
      runtime_config = Bosh::Spec::Deployments.runtime_config_with_addon_includes
      runtime_config['addons'][0]['include'] = {'jobs' => [
        {'name' => 'foobar', 'release' => 'bosh-release'}
      ]}
      runtime_config['addons'][0]['exclude'] = {'deployments' => ['dep2']}

      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell
      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

      # deploy Deployment1
      manifest_hash['name'] = 'dep1'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")

      # deploy Deployment2
      manifest_hash['name'] = 'dep2'
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0', deployment_name: 'dep2')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)

      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)
    end

    it 'allows addons to be added for specific stemcell operating systems' do
      runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon_includes_stemcell_os)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell # name: ubuntu-stemcell, os: toronto-os
      upload_stemcell_2 # name: centos-stemcell, os: toronto-centos

      manifest_hash = Bosh::Spec::NewDeployments.stemcell_os_specific_addon_manifest
      manifest_hash['stemcells'] = [
        {
          'alias' => 'toronto',
          'os' => 'toronto-os',
          'version' => 'latest',
        },
        {
          'alias' => 'centos',
          'os' => 'toronto-centos',
          'version' => 'latest'
        }
      ]

      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['vm_types'] = [
        { 'name' => 'a', 'cloud_properties' => {}, },
        { 'name' => 'b', 'cloud_properties' => {}, }
      ]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      deploy_simple_manifest(manifest_hash: manifest_hash)

      instances = director.instances

      addon_instance = instances.detect { |instance| instance.job_name == 'has-addon-vm' }
      expect(File.exist?(addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(addon_instance.job_path('dummy'))).to eq(true)

      no_addon_instance = instances.detect { |instance| instance.job_name == 'no-addon-vm' }
      expect(File.exist?(no_addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(no_addon_instance.job_path('dummy'))).to eq(false)
    end

    it 'allows addons to be added for specific networks' do
      runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon_includes_network)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell

      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['networks'] = [
        { 'name' => 'a', 'subnets' => [Bosh::Spec::NewDeployments.subnet] },
        { 'name' => 'b', 'subnets' => [Bosh::Spec::NewDeployments.subnet] }
      ]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_hash = Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell
      manifest_hash['instance_groups'] = [
        Bosh::Spec::NewDeployments.simple_instance_group(network_name: "a", name: "has-addon-vm", instances: 1),
        Bosh::Spec::NewDeployments.simple_instance_group(network_name: "b", name: "no-addon-vm", instances: 1)
      ]
      deploy_simple_manifest(manifest_hash: manifest_hash)

      instances = director.instances

      addon_instance = instances.detect { |instance| instance.job_name == 'has-addon-vm' }
      expect(File.exist?(addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(addon_instance.job_path('dummy'))).to eq(true)

      no_addon_instance = instances.detect { |instance| instance.job_name == 'no-addon-vm' }
      expect(File.exist?(no_addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(no_addon_instance.job_path('dummy'))).to eq(false)
    end

    it 'allows addons to be excluded for specific lifecycle type' do
      runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon_excludes_lifecycle)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'][1] = Bosh::Spec::NewDeployments.simple_errand_instance_group.merge({
        'name' => 'errand',
      })

      prepare_for_deploy
      deploy_simple_manifest(manifest_hash: manifest_hash)

      bosh_runner.run('run-errand -d simple  errand --keep-alive')
      instances = director.instances

      no_addon_instance = instances.detect { |instance| instance.job_name == 'errand' }
      expect(File.exist?(no_addon_instance.job_path('dummy'))).to eq(false)

      addon_instance = instances.detect { |instance| instance.job_name == 'foobar' }
      expect(File.exist?(addon_instance.job_path('dummy'))).to eq(true)
    end

    context 'when a team is specified' do
      with_reset_sandbox_before_each(user_authentication: 'uaa')

      it 'allows addons to be added for the specified team' do
        dev_team_env = {'BOSH_CLIENT' => 'dev_team', 'BOSH_CLIENT_SECRET' => 'secret'}
        production_team_env = {'BOSH_CLIENT' => 'production_team', 'BOSH_CLIENT_SECRET' => 'secret'}
        director_client_env = { client: 'director-access', client_secret: 'secret' }

        runtime_config = Bosh::Spec::Deployments.runtime_config_with_addon
        runtime_config['addons'][0]['include'] = {'teams' => ["production_team"]}
        runtime_config['addons'][0]['exclude'] = {'teams' => ["dev_team"]}
        runtime_config_file = yaml_file('runtime_config.yml', runtime_config)

        expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}", director_client_env)).to include('Succeeded')

        bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}", director_client_env)
        bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}", director_client_env)

        upload_stemcell(director_client_env)
        upload_cloud_config(director_client_env)

        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

        # deploy Deployment1
        manifest_hash['name'] = 'dep1'
        deploy_simple_manifest(manifest_hash: manifest_hash, no_login: true, env: production_team_env, include_credentials: false)

        foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1', client: production_team_env['BOSH_CLIENT'], client_secret: production_team_env['BOSH_CLIENT_SECRET'])

        expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
        template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
        expect(template).to include("echo 'addon_prop_value'")

        # deploy Deployment2
        manifest_hash['name'] = 'dep2'
        deploy_simple_manifest(manifest_hash: manifest_hash, no_login: true, env: dev_team_env, include_credentials: false)

        foobar_instance = director.instance('foobar', '0', deployment_name: 'dep2', client: dev_team_env['BOSH_CLIENT'], client_secret: dev_team_env['BOSH_CLIENT_SECRET'])

        expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)

        expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)
      end
    end

    it 'collocates addon jobs with deployment jobs and evaluates addon properties' do
      runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)

      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'addon_prop_value'")
    end

    it 'raises an error if the addon job has the same name as an existing job in an instance group' do
      runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.runtime_config_with_addon)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      manifest_hash['releases'] = [{'name' => 'bosh-release', 'version' => '0.1-dev'}, {'name' => 'dummy2', 'version' => '0.2-dev'}]
      manifest_hash['instance_groups'][0]['jobs'] = [{'name' => 'dummy_with_properties', 'release' => 'dummy2'}]

      expect { deploy_simple_manifest({manifest_hash: manifest_hash}) }.to raise_error(RuntimeError, /Colocated job 'dummy_with_properties' is already added to the instance group 'foobar'/)
    end

    it 'ensures that addon job properties are assigned' do
      runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.runtime_config_with_addon)
      runtime_config['addons'][0]['jobs'][0]['properties'] = {'dummy_with_properties' => {'echo_value' => 'new_prop_value'}}
      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell

      manifest_hash =  Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)

      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'new_prop_value'")
    end

    it 'succeeds when deployment and runtime config both have the same release with the same version' do
      runtime_config_file = yaml_file('runtime_config.yml', Bosh::Spec::Deployments.simple_runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('test_release.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('test_release_2.tgz')}")

      upload_stemcell

      manifest_hash = Bosh::Spec::NewDeployments.multiple_release_manifest
      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      deploy_output = deploy_simple_manifest(manifest_hash: manifest_hash)

      # ensure that the diff only contains one instance of the release
      expect(deploy_output.scan(/test_release_2/).count).to eq(1)
    end

    context 'when version of uploaded release is same as one used in addon and one is an integer' do
      it 'deploys it after comparing both versions as a string' do
        bosh_runner.run("upload-release #{spec_asset('test_release_2.tgz')}")

        runtime_config = Bosh::Common::DeepCopy.copy(Bosh::Spec::Deployments.simple_runtime_config)
        runtime_config['releases'][0]['version'] = 2
        runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
        expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

        upload_stemcell

        manifest_hash =  Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['releases'] = [{'name' => 'test_release_2',
          'version' => '2'}]

        manifest_hash['instance_groups'] = [Bosh::Spec::NewDeployments.simple_instance_group(
          name: 'instance_group',
          jobs: [{'name' => 'job_using_pkg_1'}],
          instances: 1,
          static_ips: ['192.168.1.10']
        )]

        upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
        deploy_simple_manifest(manifest_hash: manifest_hash)
      end
    end

    context 'when availability zones are specified' do
      it 'allows addons to be added to the runtime config' do
        runtime_config = Bosh::Spec::Deployments.runtime_config_with_addon
        runtime_config['addons'][0]['include'] = {'azs' => ['z1']}
        runtime_config['addons'][0]['exclude'] = {'azs' => ['z2']}
        runtime_config_file = yaml_file('runtime_config.yml', runtime_config)

        bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")
        expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups

        manifest_hash['name'] = 'dep1'
        manifest_hash['instance_groups'].first['azs'] = ['z1']
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs)
        foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1')
        expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
        template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
        expect(template).to include("echo 'addon_prop_value'")

        manifest_hash['name'] = 'dep2'
        manifest_hash['instance_groups'].first['azs'] = ['z2']
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs)
        foobar_instance = director.instance('foobar', '0', deployment_name: 'dep2')
        expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)
        expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)
      end

      it 'allows addons to be added to the deployment manifest' do
        bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

        manifest_hash = Bosh::Spec::NewDeployments.manifest_with_addons
        manifest_hash['addons'][0]['include'] = {'azs' => ['z1']}
        manifest_hash['addons'][0]['exclude'] = {'azs' => ['z2']}

        manifest_hash['name'] = 'dep1'
        manifest_hash['instance_groups'].first['azs'] = ['z1']

        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs)
        foobar_instance = director.instance('foobar', '0', deployment_name: 'dep1')
        expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
        template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
        expect(template).to include("echo 'prop_value'")

        manifest_hash['name'] = 'dep2'
        manifest_hash['instance_groups'].first['azs'] = ['z2']
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs)
        foobar_instance = director.instance('foobar', '0', deployment_name: 'dep2')
        expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(false)
        expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)
      end
    end
  end

  context 'when deployment' do
    it 'allows addon to be added to deployment and ensures that deployment addon job properties are assigned' do
      manifest_hash = Bosh::Spec::NewDeployments.manifest_with_addons

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell
      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0')

      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)

      template = foobar_instance.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
      expect(template).to include("echo 'prop_value'")
    end

    it 'allows to apply exclude rules' do
      manifest_hash = Bosh::Spec::NewDeployments.manifest_with_addons
      manifest_hash['addons'][0]['exclude'] = {'jobs' => [{'name' => 'foobar_without_packages', 'release' => 'bosh-release'}]}
      manifest_hash['instance_groups'][1] =
        Bosh::Spec::NewDeployments.simple_instance_group(name: 'foobar_without_packages', jobs: [{'name' => 'foobar_without_packages', 'release' => 'bosh-release'}], instances: 1)

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell

      upload_cloud_config(cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      foobar_instance = director.instance('foobar', '0')
      expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(foobar_instance.job_path('foobar'))).to eq(true)

      foobar_without_packages_instance = director.instance('foobar_without_packages', '0')
      expect(File.exist?(foobar_without_packages_instance.job_path('dummy_with_properties'))).to eq(false)
      expect(File.exist?(foobar_without_packages_instance.job_path('foobar_without_packages'))).to eq(true)
    end
  end

  context 'when deployment and runtime config' do
    it 'allows to apply the rules both from deployment manifest, and from runtime config' do
      runtime_config = Bosh::Spec::Deployments.runtime_config_with_addon
      runtime_config['addons'][0]['include'] = {'jobs' => [
        {'name' => 'foobar', 'release' => 'bosh-release'}
      ]}

      runtime_config_file = yaml_file('runtime_config.yml', runtime_config)
      expect(bosh_runner.run("update-runtime-config #{runtime_config_file.path}")).to include('Succeeded')

      manifest_hash = Bosh::Spec::NewDeployments.complex_manifest_with_addon

      bosh_runner.run("upload-release #{spec_asset('bosh-release-0+dev.1.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      upload_stemcell # name: ubuntu-stemcell, os: toronto-os
      upload_stemcell_2 # name: centos-stemcell, os: toronto-centos

      cloud_config_hash = Bosh::Spec::NewDeployments.simple_os_specific_cloud_config
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: manifest_hash)

      instances = director.instances

      rc_addon_instance = instances.detect { |instance| instance.job_name == 'has-rc-addon-vm' }
      depl_rc_addons_instance = instances.detect { |instance| instance.job_name == 'has-depl-rc-addons-vm' }
      depl_addon_instance = instances.detect { |instance| instance.job_name == 'has-depl-addon-vm' }

      expect(File.exist?(rc_addon_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(rc_addon_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(rc_addon_instance.job_path('dummy'))).to eq(false)

      expect(File.exist?(depl_rc_addons_instance.job_path('dummy_with_properties'))).to eq(true)
      expect(File.exist?(depl_rc_addons_instance.job_path('foobar'))).to eq(true)
      expect(File.exist?(depl_rc_addons_instance.job_path('dummy'))).to eq(true)

      expect(File.exist?(depl_addon_instance.job_path('dummy_with_properties'))).to eq(false)
      expect(File.exist?(depl_addon_instance.job_path('foobar_without_packages'))).to eq(true)
      expect(File.exist?(depl_addon_instance.job_path('dummy'))).to eq(true)
    end
  end

  context 'when there are default & named runtime-configs defined' do
    let(:named_runtime_config1) do
      {
        'releases' => [ {'name' => 'test_release', 'version' => '1'} ],
        'addons' => [{
                       'name' =>  'addon11',
                       'jobs' => [
                         {'name' => 'job_using_pkg_1', 'release' => 'test_release'},
                       ]
                     }],
        'tags' => {
          'foo' => 'smurfs',
          'bar' => 'gargaman',
        }
      }
    end

    let(:named_runtime_config2) do
      {
        'releases' => [ {'name' => 'test_release_2', 'version' => '2'} ],
        'addons' => [{
                       'name' =>  'addon22',
                       'jobs' => [
                         {'name' => 'job_using_pkg_2', 'release' => 'test_release_2'},
                         {'name' => 'job_using_pkg_5', 'release' => 'test_release_2'},
                       ]
                     }]
      }
    end

    before do
      default_runtime_config_file = yaml_file('runtime_config.yml',Bosh::Spec::Deployments.runtime_config_with_addon)
      named_runtime_config_file_1 = yaml_file('runtime_config.yml',named_runtime_config1)
      named_runtime_config_file_2 = yaml_file('runtime_config.yml',named_runtime_config2)

      expect(bosh_runner.run("update-runtime-config #{default_runtime_config_file.path}")).to include('Succeeded')
      expect(bosh_runner.run("update-runtime-config --name=rc_1 #{named_runtime_config_file_1.path}")).to include('Succeeded')
      expect(bosh_runner.run("update-runtime-config --name=rc_2 #{named_runtime_config_file_2.path}")).to include('Succeeded')

      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('test_release.tgz')}")
      bosh_runner.run("upload-release #{spec_asset('test_release_2.tgz')}")
    end

    it 'merges the releases & addons for a deploy' do
      deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      director.instances.each do |foobar_instance|
        expect(File.exist?(foobar_instance.job_path('foobar'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('dummy_with_package'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('job_using_pkg_1'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('job_using_pkg_2'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('job_using_pkg_5'))).to be_truthy
      end
    end

    it 'merges the tags key for a deploy' do
      deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      vms_cids = director.instances.map(&:vm_cid)
      invocations = current_sandbox.cpi.invocations.select do |invocation|
        invocation.method_name == 'set_vm_metadata' && vms_cids.include?(invocation.inputs['vm_cid'])
      end

      invocations.each do |invocation|
        expect(invocation['inputs']['metadata']['foo']).to eq('smurfs')
        expect(invocation['inputs']['metadata']['bar']).to eq('gargaman')
      end
    end

    it 'keeps the same configs versions for changing job state' do
      pending('#145206217: Changing instance groups states uses the latest cloud and runtime configs versions')
      deploy_from_scratch

      named_runtime_config1['addons'][0]['jobs'] = [
        {'name' => 'job_using_pkg_3', 'release' => 'test_release'},
      ]

      named_runtime_config_file_1 = yaml_file('runtime_config.yml',named_runtime_config1)
      expect(bosh_runner.run("update-runtime-config --name=rc_1 #{named_runtime_config_file_1.path}")).to include('Succeeded')

      bosh_runner.run('recreate -d simple')

      director.instances.each do |foobar_instance|
        expect(File.exist?(foobar_instance.job_path('job_using_pkg_1'))).to be_truthy
        expect(File.exist?(foobar_instance.job_path('job_using_pkg_3'))).to be_falsey
      end
    end

    context 'when a named runtime config is updated' do
      let(:named_runtime_config1) do
        {
          'releases' => [ {'name' => 'test_release', 'version' => '1'} ],
          'addons' => [{
                         'name' =>  'addon11',
                         'jobs' => [
                           {'name' => 'job_using_pkg_1', 'release' => 'test_release'},
                         ]
                       }],
        }
      end

      before do
        intermediate_invalid_manifest = {
          'releases' => [ {'name' => 'test_release', 'version' => '1'} ],
          'addons' => [{
                         'name' =>  'addon11',
                         'jobs' => [
                           {'name' => 'I do not exist', 'release' => 'not even once'},
                         ]
                       }],
        }
        intermediate_invalid_manifest_file = yaml_file('runtime_config.yml',intermediate_invalid_manifest)
        expect(bosh_runner.run("update-runtime-config --name=rc_1 #{intermediate_invalid_manifest_file.path}")).to include('Succeeded')


        named_runtime_config1['addons'][0]['jobs'] = [
          {'name' => 'job_using_pkg_3', 'release' => 'test_release'},
        ]

        named_runtime_config_file_1 = yaml_file('runtime_config.yml',named_runtime_config1)
        expect(bosh_runner.run("update-runtime-config --name=rc_1 #{named_runtime_config_file_1.path}")).to include('Succeeded')
      end

      it 'picks up the latest named runtime config when deploying' do
        deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

        director.instances.each do |foobar_instance|
          expect(File.exist?(foobar_instance.job_path('foobar'))).to be_truthy
          expect(File.exist?(foobar_instance.job_path('dummy_with_package'))).to be_truthy
          expect(File.exist?(foobar_instance.job_path('dummy_with_properties'))).to be_truthy
          expect(File.exist?(foobar_instance.job_path('job_using_pkg_2'))).to be_truthy
          expect(File.exist?(foobar_instance.job_path('job_using_pkg_3'))).to be_truthy
          expect(File.exist?(foobar_instance.job_path('job_using_pkg_5'))).to be_truthy

          expect(File.exist?(foobar_instance.job_path('job_using_pkg_1'))).to be_falsy
        end
      end
    end

    context 'when tags are defined in multiple runtime configs' do
      before do
        named_runtime_config2['tags'] = { 'tags_name' => 'tag_value' }
        named_runtime_config_file_2 = yaml_file('runtime_config.yml',named_runtime_config2)
        expect(bosh_runner.run("update-runtime-config --name=rc_2 #{named_runtime_config_file_2.path}")).to include('Succeeded')
      end

      it 'fails when deploying' do
        output, exit_code = deploy_from_scratch(
          failure_expected: true,
          return_exit_code: true,
          manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups,
          cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config
        )
        expect(exit_code).to_not eq(0)
        expect(output).to_not eq("Runtime config 'tags' key cannot be defined in multiple runtime configs.")
      end
    end
  end
end
