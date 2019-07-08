require_relative '../../spec_helper'

describe 'list errands', type: :integration, with_tmp_dir: true do
  with_reset_sandbox_before_each

  let(:deployment_name) { manifest_hash['name'] }

  before do
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
  end

  context('when current deployment has an instance_group lifecycle errand') do
    let(:manifest_hash) { Bosh::Spec::NewDeployments.manifest_with_errand }

    it 'lists the instance group name and the job name as errands' do
      output = bosh_runner.run('errands', deployment_name: deployment_name)
      expect(output).to match /fake-errand-name/
      expect(output).to match /errand1/
      expect(output).to match /2 errands/
    end
  end

  context('when current deployment has an instance_group lifecycle service with an errand job') do
    let(:manifest_hash) { Bosh::Spec::NewDeployments.manifest_with_errand_on_service_instance }
    it 'lists the job name as a errand' do
      output = bosh_runner.run('errands', deployment_name: deployment_name)
      expect(output).to match /errand1/
      expect(output).to match /1 errands/
    end
  end

  context 'when there are both jobs and instance groups that are errands' do
    let(:manifest_hash) do
      manifest = Bosh::Spec::NewDeployments.manifest_with_errand
      manifest['instance_groups'] << Bosh::Spec::NewDeployments.service_instance_group_with_errand
      manifest
    end

    it 'lists both the instance group name and the job name' do
      output = bosh_runner.run('errands', deployment_name: deployment_name)
      expect(output).to match /fake-errand-name/
      expect(output).to match /errand1/
      expect(output).to match /2 errands/
    end

    context 'the instance group and job have the same name' do
      let(:manifest_hash) do
        manifest = Bosh::Spec::NewDeployments.manifest_with_errand
        manifest['instance_groups'].find { |instance_group| instance_group['name'] == 'fake-errand-name'}['name'] = 'errand1'
        manifest['instance_groups'] << Bosh::Spec::NewDeployments.service_instance_group_with_errand
        manifest
      end

      it 'lists the name only once' do
        output = bosh_runner.run('errands --column=name', deployment_name: deployment_name)
        expect(output).to match /errand1/
        expect(output).to match /1 errands/
      end
    end
  end
end
