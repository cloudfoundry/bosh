require 'spec_helper'
require 'yaml'

describe "the vsphere_cpi executable" do
  it 'will not evaluate anything that causes an exception and will return the proper message to stdout' do
    config_file = Tempfile.new('cloud_properties.yml')
    config_file.write(
    {
      'cloud' => {
        'properties' => {
          'agent' => {
            'ntp' => ['ntp'],
          },
          'vcenters' => [{
            'host' => '0.0.0.0:5000',
            'user' => 'user',
            'password' => 'password',
            'datacenters' => [{
              'name' => 'datacenter_name',
              'vm_folder' => 'folder_name',
              'template_folder' => 'template_folder_name',
              'disk_path' => 'disk_path',
              'datastore_pattern' => 'datastore_pattern',
              'persistent_datastore_pattern' => 'persistent_datastore_pattern',
              'allow_mixed_datastores' => true,
              'clusters' => [
                {
                  'cluster' => {'resource_pool' => 'resource_pool_name'},
                },
                {
                  'second_cluster' => {'resource_pool' => 'second_resource_pool_name'}
                }
              ],
            }]
          }]
        }
      }
    }.to_yaml
    )
    config_file.close

    command_file = Tempfile.new('command.json')
    command_file.write({'method'=>'ping', 'arguments'=>[], 'context'=>{'director_uuid' => 'abc123'}}.to_json)
    command_file.close

    stdoutput = `bin/vsphere_cpi #{config_file.path} < #{command_file.path} 2> /dev/null`
    status = $?.exitstatus

    expect(status).to eq(0)
    result = JSON.parse(stdoutput)

    expect(result.keys).to eq(%w(result error log))

    expect(result['result']).to be_nil

    expect(result['error']).to eq({
      'type' => 'Unknown',
      'message' => 'Connection refused - connect(2) for "0.0.0.0" port 5000 (https://0.0.0.0:5000)',
      'ok_to_retry' => false
    })

    expect(result['log']).to include('backtrace')
  end

  it 'will return an appropriate error message when passed an invalid config file' do
    config_file = Tempfile.new('cloud_properties.yml')
    config_file.write({}.to_yaml)
    config_file.close

    command_file = Tempfile.new('command.json')
    command_file.write({'method'=>'ping', 'arguments'=>[], 'context'=>{'director_uuid' => 'abc123'}}.to_json)
    command_file.close

    stdoutput = `bin/vsphere_cpi #{config_file.path} < #{command_file.path} 2> /dev/null`
    status = $?.exitstatus

    expect(status).to eq(0)
    result = JSON.parse(stdoutput)

    expect(result.keys).to eq(%w(result error log))

    expect(result['result']).to be_nil

    expect(result['error']).to eq({
    'type' => 'Unknown',
    'message' => 'Could not find cloud properties in the configuration',
    'ok_to_retry' => false
    })

    expect(result['log']).to include('backtrace')
  end
end
