require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe DiskLink do
      subject { described_class.new(deployment_name, disk_name) }

      let(:deployment_name) { 'smurf_deployment' }
      let(:disk_name) { 'smurf_disk' }

      context '#spec' do
        it 'returns correct spec structure' do
          result_spec = subject.spec

          expect(result_spec).to eq({
                                      'deployment_name' => deployment_name,
                                      'properties' => { 'name' => disk_name },
                                      'networks' => [],
                                      'instances' => []
                                    })
        end
      end
    end
  end
end
