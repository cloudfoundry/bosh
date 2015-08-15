require 'spec_helper'
require 'json'

describe "the aws_cpi executable" do
  it 'will not evaluate anything that causes an exception and will return the proper message to stdout' do
    config_file = Tempfile.new('cloud_properties.yml')
    config_file.write(
    {
      'cloud' => {
        'properties' => {
          'aws' => {
            'region' => 'us-east-1',
            'default_key_name' => 'default_key_name',
            'fast_path_delete' => 'yes',
            'access_key_id' => 'access_key_id',
            'secret_access_key' => 'secret_access_key',
            'default_availability_zone' => 'subnet_zone'
          },
            'registry' => {
            'endpoint' => 'fake',
            'user' => 'fake',
            'password' => 'fake'
          }
        }
      }
    }.to_yaml
    )
    config_file.close

    command_file = Tempfile.new('command.json')
    command_file.write({'method'=>'ping', 'arguments'=>[], 'context'=>{'director_uuid' => 'abc123'}}.to_json)
    command_file.close

    stdoutput = `bin/aws_cpi #{config_file.path} < #{command_file.path} 2> /dev/null`
    status = $?.exitstatus

    expect(status).to eq(0)
    result = JSON.parse(stdoutput)

    expect(result.keys).to eq(%w(result error log))

    expect(result['result']).to be_nil

    expect(result['error']).to eq({
      'type' => 'Unknown',
      'message' => 'AWS was not able to validate the provided access credentials',
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

    stdoutput = `bin/aws_cpi #{config_file.path} < #{command_file.path} 2> /dev/null`
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
