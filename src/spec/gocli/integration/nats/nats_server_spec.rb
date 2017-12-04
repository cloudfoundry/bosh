require_relative '../../spec_helper'

describe 'nats server', type: :integration do
  let(:vm_type) do
    {
      'name' => 'smurf-vm-type',
      'cloud_properties' => {'legacy_agent_path' => get_legacy_agent_path('before-info-endpoint-20170719')}
    }
  end

  let(:cloud_config_to_enable_legacy_agent) do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config_hash['vm_types'] = [vm_type]
    cloud_config_hash
  end

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'] = [simple_instance_group]
    manifest_hash
  end

  let(:simple_instance_group) do
    {
      'name' => 'our_instance_group',
      'jobs' => [
        {
          'name' => 'job_1_with_many_properties',
          'properties' => job_properties,
        }],
      'vm_type' => 'smurf-vm-type',
      'stemcell' => 'default',
      'instances' => 1,
      'networks' => [{'name' => 'a'}]
    }
  end

  let(:job_properties) do
    {
      'gargamel' => {
        'color' => 'GARGAMEL_COLOR_IS_NOT_BLUE'
      },
      'smurfs' => {
        'happiness_level' => 2000
      }
    }
  end

  context 'is allowing legacy clients' do
    with_reset_sandbox_before_each(nats_allow_legacy_clients: true)

    context 'and connecting agent is legacy' do
      it 'should deploy successfully' do
        output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_to_enable_legacy_agent, return_exit_code: true)

        expect(exit_code).to eq(0)
        expect(output).to include('Succeeded')
      end
    end

    context 'and connecting agent is updated' do
      it 'should deploy successfully' do
        output, exit_code = deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, return_exit_code: true)

        expect(exit_code).to eq(0)
        expect(output).to include('Succeeded')
      end
    end
  end

  context 'is mutual TLS only' do
    with_reset_sandbox_before_each

    context 'and connecting agent is legacy' do
      it 'should fail the deployment' do
        output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_to_enable_legacy_agent, failure_expected: true)
        expect(output).to match(/Timed out pinging to \b.+\b after \b.+\b seconds/)
      end
    end

    context 'and connecting agent is updated' do
      it 'should deploy successfully' do
        output, exit_code = deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, return_exit_code: true)

        expect(exit_code).to eq(0)
        expect(output).to include('Succeeded')
      end
    end
  end
end
