require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe JobNetworksParser do
    let(:job_networks_parser) { JobNetworksParser.new(Network::VALID_DEFAULTS) }
    let(:job_spec) { Bosh::Spec::Deployments.simple_manifest['jobs'].first }
    let(:manifest_networks) { [Network.new('my-network', logger)] }

    context 'when job references a network not mentioned in the networks spec' do
      it 'raises JobUnknownNetwork' do
        expect {
          job_networks_parser.parse(job_spec, 'job-name', manifest_networks)
        }.to raise_error BD::JobUnknownNetwork, "Job 'job-name' references an unknown network 'a'"
      end
    end
  end
end
