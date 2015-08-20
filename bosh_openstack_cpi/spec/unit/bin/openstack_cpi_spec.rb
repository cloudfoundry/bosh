require 'spec_helper'
require 'tempfile'

describe "the openstack_cpi executable" do
  it 'will not evaluate anything that causes an exception and will return the proper message to stdout' do
    config_file = Tempfile.new('cloud_properties.yml')
    config_file.write(
      {
        'cloud' => {
          'properties' => {
            'openstack' => {
              'auth_url' => '0.0.0.0:5000/v2.0',
              'username' => 'openstack-user',
              'api_key' => 'openstack-password',
              'tenant' => 'dev',
              'region' => 'west-coast',
              'endpoint_type' => 'publicURL',
              'state_timeout' => 300,
              'boot_from_volume' => false,
              'stemcell_public_visibility' => false,
              'connection_options' => {},
              'default_key_name' => nil,
              'default_security_groups' => nil,
              'wait_resource_poll_interval' => 5,
              'config_drive' => 'disk'
            },
            'registry' => {
              'endpoint' => '0.0.0.0:5000',
              'user' => 'registry-user',
              'password' => 'registry-password',
            }
          }
        }
      }.to_yaml
    )
    config_file.close

    command_file = Tempfile.new('command.json')
    command_file.write({'method'=>'ping', 'arguments'=>[], 'context'=>{'director_uuid' => 'abc123'}}.to_json)
    command_file.close

    stdoutput = `bin/openstack_cpi #{config_file.path} < #{command_file.path} 2> /dev/null`
    status = $?.exitstatus

    expect(status).to eq(0)
    result = JSON.parse(stdoutput)

    expect(result.keys).to eq(%w(result error log))

    expect(result['result']).to be_nil

    expect(result['error']).to eq({
      'type' => 'Unknown',
      'message' => 'bad URI(is not URI?): 0.0.0.0:5000/v2.0/tokens',
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

    stdoutput = `bin/openstack_cpi #{config_file.path} < #{command_file.path} 2> /dev/null`
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
