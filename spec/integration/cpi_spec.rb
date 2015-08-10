require 'spec_helper'

describe 'CPI calls', type: :integration do
  with_reset_sandbox_before_each

  describe 'deploy' do
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
            'gateway' => '192.168.1.1'}
        },
        'disk_cids' => [],
        'env' => {}
      })

      expect(invocations[2].method_name).to eq('set_vm_metadata')
      expect(invocations[2].inputs).to match({
        'vm_cid' => String,
        'metadata' => {
          'director' => 'Test Director',
          'deployment' => 'simple',
          'job' => /compilation-.*/,
          'index' => '0'
        }
      })
      compilation_vm_id = invocations[2].inputs['vm_cid']

      expect(invocations[3].method_name).to eq('set_vm_metadata')
      expect(invocations[3].inputs).to match({
        'vm_cid' => compilation_vm_id,
        'metadata' => {
          'compiling' => 'foo', 
          'director' => 'Test Director', 
          'deployment' => 'simple',
          'job' => /compilation-.*/,
          'index' => '0'
        }
      })

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
            'gateway' => '192.168.1.1'
          }
        },
        'disk_cids' => [],
        'env' => {}
      })

      expect(invocations[6].method_name).to eq('set_vm_metadata')
      expect(invocations[6].inputs).to match({
        'vm_cid' => String,
        'metadata' => {
          'director' => 'Test Director',
          'deployment' => 'simple',
          'job' => /compilation-.*/,
          'index' => '0'
        }
      })
      compilation_vm_id = invocations[6].inputs['vm_cid']

      expect(invocations[7].method_name).to eq('set_vm_metadata')
      expect(invocations[7].inputs).to match({
        'vm_cid' => compilation_vm_id,
        'metadata' => {
          'compiling' => 'bar',
          'director' => 'Test Director',
          'deployment' => 'simple',
          'job' => /compilation-.*/,
          'index' => '0'
        }
      })

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
            'cloud_properties' =>{},
            'dns' =>['192.168.1.1', '192.168.1.2'],
            'gateway' => '192.168.1.1',
            'dns_record_name' => '0.foobar.a.simple.bosh'
          }
        },
        'disk_cids' => [],
        'env' => {}
      })

      expect(invocations[10].method_name).to eq('set_vm_metadata')
      expect(invocations[10].inputs).to match({
        'vm_cid' => String,
        'metadata' => {
          'director' => 'Test Director',
          'deployment' => 'simple',
          'job' => 'foobar',
          'index' => '0'
        }
      })

      expect(invocations.size).to eq(11)
    end
  end
end
