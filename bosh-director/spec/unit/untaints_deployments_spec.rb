require 'spec_helper'

require 'bosh/director/untaints_deployments'

module Bosh::Director
  describe UntaintsDeployments do
    let(:deployment_name) { 'deployment-name' }
    let(:manifest) { 'an_manifest' }
    let(:deployment) { double(:deployment, manifest: manifest) }
    let(:user) { double(:user) }
    let(:deployment_manager) { double('Bosh::Director::API::DeploymentManager') }
    let(:instance_one) { double('Models::Instance', job: 'an_job', index: 2) }
    let(:instance_two) { double('Models::Instance', job: 'an_job', index: 4) }
    let(:options) do
      {
        'job_states' => {
          'an_job' => {
            'instance_states' => {
              2 => 'recreate',
              4 => 'recreate'
            }
          }
        }
      }
    end
    let(:task) { double('task') }
    subject(:untaints) { described_class.new(deployment_manager, user) }

    before do
      allow(deployment_manager).to receive(:find_by_name).
        with(deployment_name).and_return(deployment)
      allow(deployment).to receive(:tainted_instances).and_return([instance_one, instance_two])
    end

    it 'creates a new untainted deployment' do
      expect(deployment_manager).to receive(:create_deployment) do |passed_user, passed_manifest, passed_options|
        expect(passed_user).to eq(user)
        expect(passed_manifest.string).to eq(manifest)
        expect(passed_options).to eq(options)
      end
      untaints.untaint_deployment!(deployment_name)
    end

    it 'returns a deployment task' do
      expect(deployment_manager).to receive(:create_deployment).and_return(task)

      expect(untaints.untaint_deployment!(deployment_name)).to eq(task)
    end
  end
end
