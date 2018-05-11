require 'spec_helper'

describe 'multiple versions of a release are uploaded', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
    cloud_config_hash['networks'].first['subnets'].first['static'] = [
      '192.168.1.10',
      '192.168.1.11',
      '192.168.1.12',
      '192.168.1.13',
    ]
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
    cloud_config_hash['compilation']['az'] = 'z1'
    cloud_config_hash['networks'] << {
      'name' => 'dynamic-network',
      'type' => 'dynamic',
      'subnets' => [{ 'az' => 'z1' }],
    }

    cloud_config_hash
  end

  let(:manifest) do
    manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
    manifest['instance_groups'] = [api_instance_group_spec, mysql_instance_group_spec, postgres_instance_group_spec]
    manifest
  end

  let(:mysql_instance_group_spec) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'mysql',
      jobs: [{ 'name' => 'database' }],
      instances: 2,
      static_ips: ['192.168.1.10', '192.168.1.11'],
    )
    spec['azs'] = ['z1']
    spec['networks'] << {
      'name' => 'dynamic-network',
      'default' => %w[dns gateway],
    }
    spec
  end

  let(:postgres_instance_group_spec) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'postgres',
      jobs: [{ 'name' => 'backup_database' }],
      instances: 1,
      static_ips: ['192.168.1.12'],
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:api_instance_group_spec) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'my_api',
      jobs: [{ 'name' => 'api_server', 'consumes' => links }],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  let(:links) do
    {
      'db' => { 'from' => 'db' },
      'backup_db' => { 'from' => 'backup_db' },
    }
  end

  let(:instance_group_consumes_link_spec) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'deployment-job',
      jobs: [{ 'name' => 'api_server', 'consumes' => links }],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:instance_group_not_consuming_links_spec) do
    spec = Bosh::Spec::NewDeployments.simple_instance_group(
      name: 'deployment-job',
      jobs: [{ 'name' => 'api_server' }],
      instances: 1,
    )
    spec['azs'] = ['z1']
    spec
  end

  it 'should only look at the specific release version templates when getting links' do
    # ####################################################################
    # 1- Deploy release version dev.1 that has jobs with links
    bosh_runner.run("upload-release #{spec_asset('links_releases/release_with_minimal_links-0+dev.1.tgz')}")
    manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
    manifest['releases'].clear
    manifest['releases'] << {
      'name' => 'release_with_minimal_links',
      'version' => '0+dev.1',
    }
    manifest['instance_groups'] = [instance_group_consumes_link_spec, mysql_instance_group_spec, postgres_instance_group_spec]

    output1, exit_code1 = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
    expect(exit_code1).to eq(0)
    expect(output1).to match(%r{Creating missing vms: deployment-job\/[a-z0-9\-]+ \(0\)})
    expect(output1).to match(%r{Creating missing vms: mysql\/[a-z0-9\-]+ \(0\)})
    expect(output1).to match(%r{Creating missing vms: mysql\/[a-z0-9\-]+ \(1\)})
    expect(output1).to match(%r{Creating missing vms: postgres\/[a-z0-9\-]+ \(0\)})

    expect(output1).to match(%r{Updating instance deployment-job: deployment-job\/[a-z0-9\-]+ \(0\)})
    expect(output1).to match(%r{Updating instance mysql: mysql\/[a-z0-9\-]+ \(0\)})
    expect(output1).to match(%r{Updating instance mysql: mysql\/[a-z0-9\-]+ \(1\)})
    expect(output1).to match(%r{Updating instance postgres: postgres\/[a-z0-9\-]+ \(0\)})

    # ####################################################################
    # 2- Deploy release version dev.2 where its jobs were updated to not have links
    bosh_runner.run("upload-release #{spec_asset('links_releases/release_with_minimal_links-0+dev.2.tgz')}")

    manifest['releases'].clear
    manifest['releases'] << {
      'name' => 'release_with_minimal_links',
      'version' => 'latest',
    }
    manifest['instance_groups'].clear
    manifest['instance_groups'] = [
      instance_group_not_consuming_links_spec,
      mysql_instance_group_spec,
      postgres_instance_group_spec,
    ]

    output2, exit_code2 = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
    expect(exit_code2).to eq(0)
    expect(output2).to_not match(%r{Creating missing vms: deployment-job\/[a-z0-9\-]+ \(0\)})
    expect(output2).to_not match(%r{Creating missing vms: mysql\/[a-z0-9\-]+ \(0\)})
    expect(output2).to_not match(%r{Creating missing vms: mysql\/[a-z0-9\-]+ \(1\)})
    expect(output2).to_not match(%r{Creating missing vms: postgres\/[a-z0-9\-]+ \(0\)})

    expect(output2).to match(%r{Updating instance deployment-job: deployment-job\/[a-z0-9\-]+ \(0\)})
    expect(output2).to match(%r{Updating instance mysql: mysql\/[a-z0-9\-]+ \(0\)})
    expect(output2).to match(%r{Updating instance mysql: mysql\/[a-z0-9\-]+ \(1\)})
    expect(output2).to match(%r{Updating instance postgres: postgres\/[a-z0-9\-]+ \(0\)})

    current_deployments = bosh_runner.run('deployments', json: true)
    # THERE IS WHITESPACE AT THE END OF THE TABLE. DO NOT REMOVE IT
    expect(table(current_deployments)).to eq([
                                               {
                                                 'name' => 'simple',
                                                 'release_s' => 'release_with_minimal_links/0+dev.2',
                                                 'stemcell_s' => 'ubuntu-stemcell/1',
                                                 'team_s' => '',
                                                 'cloud_config' => 'latest',
                                               },
                                             ])

    # ####################################################################
    # 3- Re-deploy release version dev.1 that has jobs with links. It should still work
    manifest['releases'].clear
    manifest['releases'] << {
      'name' => 'release_with_minimal_links',
      'version' => '0+dev.1',
    }
    manifest['instance_groups'] = [instance_group_consumes_link_spec, mysql_instance_group_spec, postgres_instance_group_spec]

    output3, exit_code3 = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
    expect(exit_code3).to eq(0)
    expect(output3).to_not match(%r{Creating missing vms: deployment-job\/[a-z0-9\-]+ \(0\)})
    expect(output3).to_not match(%r{Creating missing vms: mysql\/[a-z0-9\-]+ \(0\)})
    expect(output3).to_not match(%r{Creating missing vms: mysql\/[a-z0-9\-]+ \(1\)})
    expect(output3).to_not match(%r{Creating missing vms: postgres\/[a-z0-9\-]+ \(0\)})

    expect(output3).to match(%r{Updating instance deployment-job: deployment-job\/[a-z0-9\-]+ \(0\)})
    expect(output3).to match(%r{Updating instance mysql: mysql\/[a-z0-9\-]+ \(0\)})
    expect(output3).to match(%r{Updating instance mysql: mysql\/[a-z0-9\-]+ \(1\)})
    expect(output3).to match(%r{Updating instance postgres: postgres\/[a-z0-9\-]+ \(0\)})
  end

  it 'allows only the specified properties' do
    expect { deploy_simple_manifest(manifest_hash: manifest) }.to_not raise_error
  end

  context 'when a release job is being used as an addon' do
    let(:instance_group_consumes_link_spec_for_addon) do
      spec = Bosh::Spec::NewDeployments.simple_instance_group(
        name: 'deployment-job',
        jobs: [{ 'name' => 'api_server', 'consumes' => links, 'release' => 'simple-link-release' }],
      )
      spec
    end

    let(:deployment_manifest) do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['releases'].clear
      manifest['releases'] << {
        'name' => 'simple-link-release',
        'version' => '1.0',
      }

      manifest['instance_groups'] = [mysql_instance_group_spec, postgres_instance_group_spec]
      manifest['addons'] = [instance_group_consumes_link_spec_for_addon]
      manifest
    end

    it 'should ONLY use the release version specified in manifest' do
      bosh_runner.run("upload-release #{spec_asset('links_releases/simple-link-release-v1.0.tgz')}")

      _, exit_code1 = deploy_simple_manifest(manifest_hash: deployment_manifest, return_exit_code: true)
      expect(exit_code1).to eq(0)

      deployed_instances = director.instances
      mysql_0_instance = director.find_instance(deployed_instances, 'mysql', '0')
      mysql_1_instance = director.find_instance(deployed_instances, 'mysql', '1')
      postgres_0_instance = director.find_instance(deployed_instances, 'postgres', '0')

      mysql_template1 = YAML.safe_load(mysql_0_instance.read_job_template('api_server', 'config.yml'))
      expect(mysql_template1['databases']['main'].size).to eq(2)
      expect(mysql_template1['databases']['main']).to contain_exactly(
        {
          'id' => mysql_0_instance.id.to_s,
          'name' => 'mysql',
          'index' => 0,
          'address' => anything,
        },
        {
          'id' => mysql_1_instance.id.to_s,
          'name' => 'mysql',
          'index' => 1,
          'address' => anything,
        },
      )

      expect(mysql_template1['databases']['backup']).to contain_exactly(
        'name' => 'postgres',
        'az' => 'z1',
        'index' => 0,
        'address' => anything,
      )

      postgres_template2 = YAML.safe_load(postgres_0_instance.read_job_template('api_server', 'config.yml'))
      expect(postgres_template2['databases']['main'].size).to eq(2)
      expect(postgres_template2['databases']['main']).to contain_exactly(
        {
          'id' => mysql_0_instance.id.to_s,
          'name' => 'mysql',
          'index' => 0,
          'address' => anything,
        },
        {
          'id' => mysql_1_instance.id.to_s,
          'name' => 'mysql',
          'index' => 1,
          'address' => anything,
        },
      )

      expect(postgres_template2['databases']['backup']).to contain_exactly(
        'name' => 'postgres',
        'az' => 'z1',
        'index' => 0,
        'address' => anything,
      )

      bosh_runner.run("upload-release #{spec_asset('links_releases/simple-link-release-v2.0.tgz')}")

      _, exit_code2 = deploy_simple_manifest(manifest_hash: deployment_manifest, return_exit_code: true)
      expect(exit_code2).to eq(0)
    end
  end
end
