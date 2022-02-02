require 'spec_helper'

describe 'exporting release with templates that have links', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: true)
    bosh_runner.run_in_dir('create-release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:cloud_config) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
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

  let(:mongo_db_spec) do
    spec = Bosh::Spec::Deployments.simple_instance_group(
      name: 'mongo',
      jobs: [{ 'name' => 'mongo_db', 'release' => 'bosh-release' }],
      instances: 1,
      static_ips: ['192.168.1.13'],
    )
    spec['azs'] = ['z1']
    spec
  end

  let(:manifest) do
    manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
    manifest['instance_groups'] = [mongo_db_spec]

    # We manually change the deployment manifest release version, beacuse of w weird issue where
    # the uploaded release version is `0+dev.1` and the release version in the deployment manifest
    # is `0.1-dev`
    manifest['releases'][0]['version'] = '0+dev.1'

    manifest
  end

  before do
    upload_links_release
    upload_stemcell

    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  it 'should successfully compile a release without complaining about missing links in sha2 mode', sha2: true do
    deploy_simple_manifest(manifest_hash: manifest)
    out = bosh_runner.run('export-release bosh-release/0+dev.1 toronto-os/1', deployment_name: 'simple')

    expect(out).to include('Preparing package compilation: Finding packages to compile')
    expect(out).to match(%r{Compiling packages: pkg_2\/[a-f0-9]+})
    expect(out).to match(%r{Compiling packages: pkg_3_depends_on_2\/[a-f0-9]+})
    expect(out).to match(%r{copying packages: pkg_1\/[a-f0-9]+})
    expect(out).to match(%r{copying packages: pkg_3_depends_on_2\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: addon\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_bad_link_types\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_bad_optional_links\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_optional_db_link\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_optional_links_1\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_optional_links_2\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: backup_database\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: consumer\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: database\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: database_with_two_provided_link_of_same_type\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: http_endpoint_provider_with_property_types\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: http_proxy_with_requires\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: http_server_with_provides\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: kv_http_server\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: mongo_db\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: node\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: provider\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: provider_fail\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: tcp_proxy_with_requires\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: tcp_server_with_provides\/[a-f0-9]+})

    expect(out).to include('Succeeded')
  end

  it 'should successfully compile a release without complaining about missing links in sha1 mode', sha1: true do
    deploy_simple_manifest(manifest_hash: manifest)
    out = bosh_runner.run('export-release bosh-release/0+dev.1 toronto-os/1', deployment_name: 'simple')

    expect(out).to include('Preparing package compilation: Finding packages to compile')
    expect(out).to match(%r{Compiling packages: pkg_2\/[a-f0-9]+})
    expect(out).to match(%r{Compiling packages: pkg_3_depends_on_2\/[a-f0-9]+})
    expect(out).to match(%r{copying packages: pkg_1\/[a-f0-9]+})
    expect(out).to match(%r{copying packages: pkg_3_depends_on_2\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: addon\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_bad_link_types\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_bad_optional_links\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_optional_db_link\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_optional_links_1\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: api_server_with_optional_links_2\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: backup_database\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: consumer\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: database\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: database_with_two_provided_link_of_same_type\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: http_endpoint_provider_with_property_types\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: http_proxy_with_requires\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: http_server_with_provides\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: kv_http_server\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: mongo_db\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: node\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: provider\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: provider_fail\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: tcp_proxy_with_requires\/[a-f0-9]+})
    expect(out).to match(%r{copying jobs: tcp_server_with_provides\/[a-f0-9]+})

    expect(out).to include('Succeeded')
  end
end
