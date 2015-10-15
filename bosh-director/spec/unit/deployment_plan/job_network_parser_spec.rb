require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe JobNetworksParser do
    let(:job_networks_parser) { JobNetworksParser.new(Network::VALID_DEFAULTS) }
    let(:job_spec) do
      Bosh::Spec::Deployments.simple_manifest['jobs'].first
    end

    let(:deployment) { instance_double(Planner) }

    context 'when job references a network not mentioned in the networks spec' do
      it 'raises JobUnknownNetwork' do
        expect(deployment).to receive(:network).with('a').and_return(nil)

        expect {
          job_networks_parser.parse(job_spec, 'job-name', deployment)
        }.to raise_error BD::JobUnknownNetwork, "Job 'job-name' references an unknown network 'a'"
      end
    end
  end
end
