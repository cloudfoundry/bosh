require_relative '../../spec_helper'

describe 'nats server', type: :integration do
  let(:vm_type) do
    {
      'name' => 'smurf-vm-type',
    }
  end

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
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

  context 'is mutual TLS only' do
    with_reset_sandbox_before_each

    it 'should deploy successfully' do
      output, exit_code = deploy_from_scratch(
        manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups,
        return_exit_code: true,
      )

      expect(exit_code).to eq(0)
      expect(output).to include('Succeeded')
    end
  end

  context 'with nats.pure' do
    with_reset_sandbox_before_each(use_nats_pure: true)

    it 'should deploy successfully' do
      output, exit_code = deploy_from_scratch(
        manifest_hash: Bosh::Spec::Deployments.simple_manifest_with_instance_groups,
        return_exit_code: true,
      )

      expect(exit_code).to eq(0)
      expect(output).to include('Succeeded')
    end
  end
end
