require 'spec_helper'

describe 'collocating templates from 2 releases' do
  include IntegrationExampleGroup

  it 'refuses to deploy when 2 templates depend on packages with the same name' do

    extras = {
      'name' => 'simple',
      'releases' => [
        {
          'name' => 'dummy',
          'version' => 'latest',
        },
        {
          'name' => 'dummy2',
          'version' => 'latest',
        },
      ],

      'networks' => [
        {
          'name' => 'a',
          'subnets' => [
            {
              'range' => '192.168.1.0/24',
              'gateway' => '192.168.1.1',
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'static' => ['192.168.1.10'],
              'reserved' => [],
              'cloud_properties' => {},
            }
          ]
        }
      ],

      'resource_pools' => [
        {
          'name' => 'a',
          'size' => 3,
          'cloud_properties' => {},
          'network' => 'a',
          'stemcell' => {
            'name' => 'ubuntu-stemcell',
            'version' => '1'
          }
        }
      ],

      'jobs' => [
        {
          'name' => 'foobar',
          'templates' => [
            {
              'name' => 'dummy_with_package',
              'release' => 'dummy',
            },
            {
              'name' => 'template2',
              'release' => 'dummy2',
            },
          ],

          'resource_pool' => 'a',
          'instances' => 1,
          'networks' => [{'name' => 'a'}]
        }
      ]
    }

    minimal_manifest = Bosh::Spec::Deployments.minimal_manifest
    minimal_manifest.delete('release')
    manifest_hash = minimal_manifest.merge(extras)

    output = deploy_simple_with_collocation(manifest_hash: manifest_hash, expect_failure: true)
    output.should =~ /Unable to deploy: package name collision in job definitions/
  end
end
