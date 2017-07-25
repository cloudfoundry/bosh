require_relative '../../spec_helper'

describe 'run-errand success', type: :integration, with_tmp_dir: true do
  let(:deployment_name) { manifest_hash['name'] }

  with_reset_sandbox_before_each

  context 'when running errands on service instances' do
    let(:manifest_hash) { Bosh::Spec::Deployments.manifest_with_errand_job_on_service_instance }

    it 'runs the errand referenced by the job name on a service lifecycle instance' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name)

      expect(output).to match /fake-errand-stdout-service/
      expect(output).to match /Succeeded/
    end

    it 'runs the errand referenced by the job name on multiple service lifecycle instances' do
      manifest_hash['jobs'][0]['instances'] = 2

      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name)

      expect(output).to match /job=service_with_errand index=0/
      expect(output).to match /job=service_with_errand index=1/
      expect(output.scan('fake-errand-stdout-service').size).to eq(2)
      expect(output.scan('stdout-from-errand1-package').size).to eq(2)

      expect(output).to match /Succeeded/
    end
  end

  context 'when lifecycle service instance groups and lifecycle errand instance groups have the errand job' do
    let(:manifest_hash) do
      hash = Bosh::Spec::Deployments.manifest_with_errand
      hash['jobs'] <<  service_job_with_errand
      hash
    end

    let(:service_job_with_errand) do
      instance_group = Bosh::Spec::Deployments.service_job_with_errand
      instance_group['instances'] = 2
      instance_group
    end

    it 'runs the errand on all instances' do
      deploy_from_scratch(manifest_hash: manifest_hash)

      output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name)
      puts output

      expect(output).to match /job=service_with_errand index=0/
      expect(output).to match /job=service_with_errand index=1/
      expect(output).to match /job=fake-errand-name index=0/
      expect(output.scan(/fake-errand-stdout-service/).size).to eq(2)
      expect(output.scan(/fake-errand-stdout[^\-]/).size).to eq(1)

      expect(output).to match /Succeeded/

      output = bosh_runner.run('task 4 --result', deployment_name: deployment_name)
      puts output
    end
  end
end
