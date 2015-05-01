require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::CloudManifestParser do
    subject(:parser) { described_class.new(deployment, logger) }
    let(:deployment) { DeploymentPlan::Planner.new(planner_attributes, {}, cloud_manifest, nil) }
    let(:planner_attributes) {
      {
        name: 'deployment-name',
        properties: {}
      }
    }
    let(:event_log) { Config.event_log }

    describe '#parse' do
      let(:parsed_deployment) { subject.parse(cloud_manifest) }

      before { allow(DeploymentPlan::CompilationConfig).to receive(:new).and_return(compilation_config) }
      let(:compilation_config) { instance_double('Bosh::Director::DeploymentPlan::CompilationConfig') }

      let(:cloud_manifest) { Bosh::Spec::Deployments.simple_cloud_config }

      describe 'compilation' do
        context 'when compilation section is specified' do
          before { cloud_manifest.merge!('compilation' => { 'foo' => 'bar' }) }

          it 'delegates parsing to CompilationConfig' do
            compilation = instance_double('Bosh::Director::DeploymentPlan::CompilationConfig')

            expect(DeploymentPlan::CompilationConfig).to receive(:new).
                with(be_a(DeploymentPlan::Planner), 'foo' => 'bar').
                and_return(compilation)

            expect(parsed_deployment.compilation).to eq(compilation)
          end
        end

        context 'when compilation section is not specified' do
          before { cloud_manifest.delete('compilation') }

          it 'raises an error' do
            expect {
              parsed_deployment
            }.to raise_error(
                ValidationMissingField,
                /Required property `compilation' was not specified in object .+/,
              )
          end
        end
      end

      describe 'networks' do
        context 'when there is at least one network' do
          context 'when network type is not specified' do
            before do
              cloud_manifest.merge!(
                'networks' => [{
                    'name' => 'a',
                    'subnets' => [],
                  }])
            end

            it 'should create manual network by default' do
              expect(parsed_deployment.networks.count).to eq(1)
              expect(parsed_deployment.networks.first).to be_a(DeploymentPlan::ManualNetwork)
              expect(parsed_deployment.networks.first.name).to eq('a')
            end

            it 'allows to look up network by name' do
              expect(parsed_deployment.network('a')).to be_a(DeploymentPlan::ManualNetwork)
              expect(parsed_deployment.network('b')).to be_nil
            end
          end

          context 'when network type is manual'
          context 'when network type is dynamic'
          context 'when network type is vip'
          context 'when network type is unknown'

          context 'when more than one network have same canonical name' do
            before do
              cloud_manifest['networks'] = [
                { 'name' => 'bar', 'subnets' => [] },
                { 'name' => 'Bar', 'subnets' => [] },
              ]
            end

            it 'raises an error' do
              expect {
                parsed_deployment
              }.to raise_error(
                  DeploymentCanonicalNetworkNameTaken,
                  "Invalid network name `Bar', canonical name already taken",
                )
            end
          end
        end

        context 'when 0 networks are specified' do
          before { cloud_manifest.merge!('networks' => []) }

          it 'raises an error because deployment must have at least one network' do
            expect {
              parsed_deployment
            }.to raise_error(DeploymentNoNetworks, 'No networks specified')
          end
        end

        context 'when networks key is not specified' do
          before { cloud_manifest.delete('networks') }

          it 'raises an error because deployment must have at least one network' do
            expect {
              parsed_deployment
            }.to raise_error(
                ValidationMissingField,
                /Required property `networks' was not specified in object .+/,
              )
          end
        end
      end

      describe 'resource_pools' do
        context 'when there is at least one resource_pool' do
          context 'when each resource pool has a unique name' do
            before do
              cloud_manifest['resource_pools'] = [
                Bosh::Spec::Deployments.resource_pool.merge('name' => 'rp1-name'),
                Bosh::Spec::Deployments.resource_pool.merge('name' => 'rp2-name')
              ]
            end

            it 'creates ResourcePools for each entry' do
              expect(parsed_deployment.resource_pools.map(&:class)).to eq([DeploymentPlan::ResourcePool, DeploymentPlan::ResourcePool])
              expect(parsed_deployment.resource_pools.map(&:name)).to eq(['rp1-name', 'rp2-name'])
            end

            it 'allows to look up resource_pool by name' do
              expect(parsed_deployment.resource_pool('rp1-name').name).to eq('rp1-name')
              expect(parsed_deployment.resource_pool('rp2-name').name).to eq('rp2-name')
            end
          end

          context 'when more than one resource pool have same name' do
            before do
              cloud_manifest['resource_pools'] = [
                Bosh::Spec::Deployments.resource_pool.merge({ 'name' => 'same-name' }),
                Bosh::Spec::Deployments.resource_pool.merge({ 'name' => 'same-name' })
              ]
            end

            it 'raises an error' do
              expect {
                parsed_deployment
              }.to raise_error(
                  DeploymentDuplicateResourcePoolName,
                  "Duplicate resource pool name `same-name'",
                )
            end
          end
        end

        context 'when there are no resource pools' do
          before do
            cloud_manifest['resource_pools'] = []
          end

          it 'raises an error' do
            expect {
              parsed_deployment
            }.to raise_error(
                DeploymentNoResourcePools,
                "No resource_pools specified",
              )
          end
        end
      end

      describe 'disk_pools' do
        context 'when there is at least one disk_pool' do
          context 'when each resource pool has a unique name' do
            before do
              cloud_manifest['disk_pools'] = [
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'dk1-name' }),
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'dk2-name' })
              ]
            end

            it 'creates DiskPools for each entry' do
              expect(parsed_deployment.disk_pools.map(&:class)).to eq([DeploymentPlan::DiskPool, DeploymentPlan::DiskPool])
              expect(parsed_deployment.disk_pools.map(&:name)).to eq(['dk1-name', 'dk2-name'])
            end

            it 'allows to look up disk_pool by name' do
              expect(parsed_deployment.disk_pool('dk1-name').name).to eq('dk1-name')
              expect(parsed_deployment.disk_pool('dk2-name').name).to eq('dk2-name')
            end
          end

          context 'when more than one disk pool have same name' do
            before do
              cloud_manifest['disk_pools'] = [
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'same-name' }),
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'same-name' })
              ]
            end

            it 'raises an error' do
              expect {
                parsed_deployment
              }.to raise_error(
                  DeploymentDuplicateDiskPoolName,
                  "Duplicate disk pool name `same-name'",
                )
            end
          end
        end
      end
    end
  end
end
