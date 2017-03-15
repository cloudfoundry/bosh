require_relative '../spec_helper'

describe 'CPI calls', type: :integration do
  with_reset_sandbox_before_each

  def expect_name(invocation)
    expect(invocation.inputs['metadata']['name']).to eq("#{invocation.inputs['metadata']['job']}/#{invocation.inputs['metadata']['id']}")
  end

  describe 'deploy' do
    let(:expected_groups) {
      ['testdirector', 'simple', 'first-job', 'testdirector-simple', 'simple-first-job', 'testdirector-simple-first-job']
    }
    let(:expected_group) { 'testdirector-simple-first-job' }

    it 'sends correct CPI requests' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_from_scratch(manifest_hash: manifest_hash)

      invocations = current_sandbox.cpi.invocations

      expect(invocations[0].method_name).to eq('create_stemcell')
      expect(invocations[0].inputs).to match({
        'image_path' => String,
        'cloud_properties' => {'property1' => 'test', 'property2' => 'test'}
      })

      expect(invocations[1].method_name).to eq('create_vm')
      expect(invocations[1].inputs).to match({
        'agent_id' => String,
        'stemcell_id' => String,
        'cloud_properties' => {},
        'networks' => {
          'a' => {
            'ip' => '192.168.1.3',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {},
            'default' => ['dns', 'gateway'],
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'gateway' => '192.168.1.1',
          }
        },
        'disk_cids' => [],
        'env' => { 'bosh' => { 'group' => String, 'groups' => Array } }
      })

      expect(invocations[2].method_name).to eq('set_vm_metadata')
      expect(invocations[2].inputs).to match({
        'vm_cid' => String,
        'metadata' => {
          'director' => 'TestDirector',
          'created_at' => kind_of(String),
          'deployment' => 'simple',
          'job' => /compilation-.*/,
          'index' => '0',
          'id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
          'name' => /compilation-.*\/[0-9a-f]{8}-[0-9a-f-]{27}/
        }
      })
      expect_name(invocations[2])
      compilation_vm_id = invocations[2].inputs['vm_cid']

      expect(invocations[3].method_name).to eq('set_vm_metadata')
      expect(invocations[3].inputs).to match({
        'vm_cid' => compilation_vm_id,
        'metadata' => {
          'compiling' => 'foo',
          'director' => 'TestDirector',
          'created_at' => kind_of(String),
          'deployment' => 'simple',
          'job' => /compilation-.*/,
          'index' => '0',
          'id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
          'name' => /compilation-.*\/[0-9a-f]{8}-[0-9a-f-]{27}/
      }
      })
      expect_name(invocations[3])
      expect(invocations[4].method_name).to eq('delete_vm')
      expect(invocations[4].inputs).to match({'vm_cid' => compilation_vm_id})

      expect(invocations[5].method_name).to eq('create_vm')
      expect(invocations[5].inputs).to match({
        'agent_id' => String,
        'stemcell_id' => String,
        'cloud_properties' => {},
        'networks' => {
          'a' => {
            'ip' => '192.168.1.3',
            'netmask' => '255.255.255.0',
            'cloud_properties' => {},
            'default' => ['dns', 'gateway'],
            'dns' => ['192.168.1.1', '192.168.1.2'],
            'gateway' => '192.168.1.1',
          }
        },
        'disk_cids' => [],
        'env' => { 'bosh' => { 'group' => String, 'groups' => Array } }
      })

      expect(invocations[6].method_name).to eq('set_vm_metadata')
      expect(invocations[6].inputs).to match({
        'vm_cid' => String,
        'metadata' => {
          'director' => 'TestDirector',
          'created_at' => kind_of(String),
          'deployment' => 'simple',
          'job' => /compilation-.*/,
          'index' => '0',
          'id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
          'name' => /compilation-.*\/[0-9a-f]{8}-[0-9a-f-]{27}/
        }
      })
      expect_name(invocations[6])
      compilation_vm_id = invocations[6].inputs['vm_cid']

      expect(invocations[7].method_name).to eq('set_vm_metadata')
      expect(invocations[7].inputs).to match({
        'vm_cid' => compilation_vm_id,
        'metadata' => {
          'compiling' => 'bar',
          'created_at' => kind_of(String),
          'director' => 'TestDirector',
          'deployment' => 'simple',
          'job' => /compilation-.*/,
          'index' => '0',
          'id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
          'name' => /compilation-.*\/[0-9a-f]{8}-[0-9a-f-]{27}/
        }
      })
      expect_name(invocations[7])

      expect(invocations[8].method_name).to eq('delete_vm')
      expect(invocations[8].inputs).to match({'vm_cid' => compilation_vm_id})

      expect(invocations[9].method_name).to eq('create_vm')
      expect(invocations[9].inputs).to match({
        'agent_id' => String,
        'stemcell_id' => String,
        'cloud_properties' =>{},
        'networks' => {
          'a' => {
            'ip' => '192.168.1.2',
            'netmask' => '255.255.255.0',
            'default' => ['dns', 'gateway'],
            'cloud_properties' =>{},
            'dns' =>['192.168.1.1', '192.168.1.2'],
            'gateway' => '192.168.1.1',
          }
        },
        'disk_cids' => [],
        'env' => {'bosh' =>{'password' => 'foobar', 'group' => 'testdirector-simple-foobar', 'groups' => ['testdirector', 'simple', 'foobar', 'testdirector-simple', 'simple-foobar', 'testdirector-simple-foobar']}}
      })

      expect(invocations[10].method_name).to eq('set_vm_metadata')
      expect(invocations[10].inputs).to match({
        'vm_cid' => String,
        'metadata' => {
          'director' => 'TestDirector',
          'created_at' => kind_of(String),
          'deployment' => 'simple',
          'job' => 'foobar',
          'index' => '0',
          'id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
          'name' => /foobar\/[0-9a-f]{8}-[0-9a-f-]{27}/
        }
      })
      expect_name(invocations[10])

      expect(invocations.size).to eq(11)
    end

    context 'when deploying instances with a persistent disk' do
      it 'recreates VM with correct CPI requests' do
        manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest_hash['jobs'] = [
          Bosh::Spec::Deployments.simple_job(
            name: 'first-job',
            static_ips: ['192.168.1.10'],
            instances: 1,
            templates: ['name' => 'foobar_without_packages'],
            persistent_disk_pool: Bosh::Spec::Deployments.disk_pool['name']
          )
        ]
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11']
        cloud_config_hash['disk_pools'] = [Bosh::Spec::Deployments.disk_pool]
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)
        first_deploy_invocations = current_sandbox.cpi.invocations

        expect(first_deploy_invocations[0].method_name).to eq('create_stemcell')
        expect(first_deploy_invocations[0].inputs).to match({
          'image_path' => String,
          'cloud_properties' => {
            'property1' => 'test',
            'property2' => 'test'
          }
        })

        expect(first_deploy_invocations[1].method_name).to eq('create_vm')
        expect(first_deploy_invocations[1].inputs).to match({
          'agent_id' => String,
          'stemcell_id' => String,
          'cloud_properties' => {},
          'networks' => {
            'a' => {
              'ip' => '192.168.1.10',
              'netmask' => '255.255.255.0',
              'cloud_properties' => {},
              'default' => ['dns', 'gateway'],
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'gateway' => '192.168.1.1',
            }
          },
          'disk_cids' => [],
          'env' => {'bosh' =>{'password' => 'foobar', 'group' => expected_group, 'groups' => expected_groups}}
        })

        expect(first_deploy_invocations[2].method_name).to eq('set_vm_metadata')
        expect(first_deploy_invocations[2].inputs).to match({
          'vm_cid' => String,
          'metadata' => {
            'director' => 'TestDirector',
            'created_at' => kind_of(String),
            'deployment' => 'simple',
            'job' => 'first-job',
            'index' => '0',
            'id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
            'name' => /first-job\/[0-9a-f]{8}-[0-9a-f-]{27}/
          }
        })
        expect_name(first_deploy_invocations[2])
        vm_cid = first_deploy_invocations[2].inputs['vm_cid']

        expect(first_deploy_invocations[3].method_name).to eq('create_disk')
        expect(first_deploy_invocations[3].inputs).to match({
          'size' => 123,
          'cloud_properties' => {},
          'vm_locality' => vm_cid
        })

        expect(first_deploy_invocations[4].method_name).to eq('attach_disk')
        expect(first_deploy_invocations[4].inputs).to match({
          'vm_cid' => vm_cid,
          'disk_id' => String
        })
        disk_cid = first_deploy_invocations[4].inputs['disk_id']

        expect(first_deploy_invocations[5].method_name).to eq('set_disk_metadata')
        expect(first_deploy_invocations[5].inputs).to match({
          'disk_cid' => disk_cid,
          'metadata' => {
            'director' => 'TestDirector',
            'attached_at' => kind_of(String),
            'deployment' => 'simple',
            'job' => 'first-job',
            'instance_index' => '0',
            'instance_id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
            'instance_name' => /first-job\/[0-9a-f]{8}-[0-9a-f-]{27}/
          }
        })

        manifest_hash['jobs'].first['networks'].first['static_ips'] = ['192.168.1.11']

        # add tags
        manifest_hash.merge!({
          'tags' => {
            'tag1' => 'value1',
          },
        })

        # upload runtime config with tags
        runtime_config_hash = {
          'releases' => [{'name' => 'test_release_2', 'version' => '2'}],
          'tags' => {
            'tag2' => 'value2',
          },
        }

        bosh_runner.run("upload-release #{spec_asset('test_release_2.tgz')}")
        upload_runtime_config(runtime_config_hash: runtime_config_hash)

        deploy_simple_manifest(manifest_hash: manifest_hash)

        second_deploy_invocations = current_sandbox.cpi.invocations.drop(first_deploy_invocations.size)

        expect(second_deploy_invocations[0].method_name).to eq('snapshot_disk')
        expect(second_deploy_invocations[0].inputs).to match({
          'disk_id' => disk_cid,
          'metadata' => {
            'deployment' => 'simple',
            'job' => 'first-job',
            'index' => 0,
            'director_name' => 'TestDirector',
            'director_uuid' => 'deadbeef',
            'agent_id' => String
          }
        })

        expect(second_deploy_invocations[1].method_name).to eq('delete_vm')
        expect(second_deploy_invocations[1].inputs).to match({
          'vm_cid' => vm_cid
        })

        expect(second_deploy_invocations[2].method_name).to eq('create_vm')
        expect(second_deploy_invocations[2].inputs).to match({
          'agent_id' => String,
          'stemcell_id' => String,
          'cloud_properties' => {},
          'networks' => {
            'a' => {
              'ip' => '192.168.1.11',
              'netmask' => '255.255.255.0',
              'cloud_properties' => {},
              'default' => ['dns', 'gateway'],
              'dns' => ['192.168.1.1', '192.168.1.2'],
              'gateway' => '192.168.1.1',
            }
          },
          'disk_cids' => [disk_cid],
          'env' => {'bosh' =>{'password' => 'foobar', 'group' => expected_group, 'groups' => expected_groups}}
        })

        expect(second_deploy_invocations[3].method_name).to eq('set_vm_metadata')
        expect(second_deploy_invocations[3].inputs).to match({
          'vm_cid' => String,
          'metadata' => {
            'director' => 'TestDirector',
            'created_at' => kind_of(String),
            'deployment' => 'simple',
            'job' => 'first-job',
            'index' => '0',
            'id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
            'name' => /first-job\/[0-9a-f]{8}-[0-9a-f-]{27}/,
            'tag1' => 'value1',
            'tag2' => 'value2'
          }
        })

        expect_name(second_deploy_invocations[3])

        new_vm_cid = second_deploy_invocations[3].inputs['vm_cid']

        expect(second_deploy_invocations[4].method_name).to eq('attach_disk')
        expect(second_deploy_invocations[4].inputs).to match({
          'vm_cid' => new_vm_cid,
          'disk_id' => disk_cid
        })

        expect(second_deploy_invocations[5].method_name).to eq('set_disk_metadata')
        expect(second_deploy_invocations[5].inputs).to match({
          'disk_cid' => disk_cid,
          'metadata' => {
            'director' => 'TestDirector',
            'attached_at' => kind_of(String),
            'deployment' => 'simple',
            'job' => 'first-job',
            'instance_index' => '0',
            'instance_id' => /[0-9a-f]{8}-[0-9a-f-]{27}/,
            'instance_name' => /first-job\/[0-9a-f]{8}-[0-9a-f-]{27}/,
            'tag1' => 'value1',
            'tag2' => 'value2'
          }
        })
      end
    end
  end
end
