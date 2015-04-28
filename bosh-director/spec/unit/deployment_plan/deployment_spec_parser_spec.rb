require 'spec_helper'
require 'bosh/director/dns_helper'

module Bosh::Director
  describe DeploymentPlan::DeploymentSpecParser do
    subject(:parser) { described_class.new(event_log, logger) }
    let(:event_log) { Config.event_log }

    describe '#parse' do
      let(:deployment) { subject.parse(planner_attributes, manifest_hash, cloud_config, deployment_model) }
      let(:deployment_model) { Models::Deployment.make }
      let(:manifest_hash) do
        {
          'name' => 'deployment-name',
          'releases' => [],
          'networks' => [{ 'name' => 'network-name' }],
          'compilation' => {},
          'update' => {},
          'resource_pools' => [],
        }
      end
      let(:planner_attributes) {
        {
          name: manifest_hash['name'],
          properties: manifest_hash['properties'] || {}
        }
      }

      before { allow(DeploymentPlan::CompilationConfig).to receive(:new).and_return(compilation_config) }
      let(:compilation_config) { instance_double('Bosh::Director::DeploymentPlan::CompilationConfig') }

      before { allow(DeploymentPlan::UpdateConfig).to receive(:new).and_return(update_config) }
      let(:update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig') }
      let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config }
      let(:cloud_config) { Models::CloudConfig.make(manifest: cloud_config_hash) }

      describe 'name key' do
        it 'parses name' do
          manifest_hash.merge!('name' => 'Name with spaces')
          expect(deployment.name).to eq('Name with spaces')
        end

        it 'sets canonical name' do
          manifest_hash.merge!('name' => 'Name with spaces')
          expect(deployment.canonical_name).to eq('namewithspaces')
        end
      end

      describe 'properties key' do
        it 'parses basic properties' do
          manifest_hash.merge!('properties' => { 'foo' => 'bar' })
          expect(deployment.properties).to eq('foo' => 'bar')
        end

        it 'allows to not include properties key' do
          manifest_hash.delete('properties')
          expect(deployment.properties).to eq({})
        end
      end

      describe 'releases/release key' do
        let(:releases_spec) do
          [
            { 'name' => 'foo', 'version' => '27' },
            { 'name' => 'bar', 'version' => '42' },
          ]
        end

        context "when 'release' section is specified" do
          before do
            manifest_hash.delete('releases')
            manifest_hash.merge!('release' => {'name' => 'rv-name', 'version' => 'abc'})
          end

          it 'delegates to ReleaseVersion' do
            expect(deployment.releases.size).to eq(1)
            release_version = deployment.releases.first
            expect(release_version).to be_a(DeploymentPlan::ReleaseVersion)
            expect(release_version.name).to eq('rv-name')
          end

          it 'allows to look up release by name' do
            release_version = deployment.release('rv-name')
            expect(release_version).to be_a(DeploymentPlan::ReleaseVersion)
            expect(release_version.name).to eq('rv-name')
          end
        end

        context "when 'releases' section is specified" do
          before { manifest_hash.delete('release') }

          context 'when non-duplicate releases are included' do
            before do
              manifest_hash.merge!('releases' => [
                {'name' => 'rv1-name', 'version' => 'abc'},
                {'name' => 'rv2-name', 'version' => 'def'},
              ])
            end

            it 'delegates to ReleaseVersion' do
              expect(deployment.releases.size).to eq(2)

              rv1 = deployment.releases.first
              expect(rv1).to be_a(DeploymentPlan::ReleaseVersion)
              expect(rv1.name).to eq('rv1-name')
              expect(rv1.version).to eq('abc')

              rv2 = deployment.releases.last
              expect(rv2).to be_a(DeploymentPlan::ReleaseVersion)
              expect(rv2.name).to eq('rv2-name')
              expect(rv2.version).to eq('def')
            end

            it 'allows to look up release by name' do
              rv1 = deployment.release('rv1-name')
              expect(rv1).to be_a(DeploymentPlan::ReleaseVersion)
              expect(rv1.name).to eq('rv1-name')
              expect(rv1.version).to eq('abc')

              rv2 = deployment.release('rv2-name')
              expect(rv2).to be_a(DeploymentPlan::ReleaseVersion)
              expect(rv2.name).to eq('rv2-name')
              expect(rv2.version).to eq('def')
            end
          end

          context 'when duplicate releases are included' do
            before do
              manifest_hash.merge!('releases' => [
                {'name' => 'same-name', 'version' => 'abc'},
                {'name' => 'same-name', 'version' => 'def'},
              ])
            end

            it 'raises an error' do
              expect {
                deployment
              }.to raise_error(/duplicate release name/i)
            end
          end
        end

        context "when both 'releases' and 'release' sections are specified" do
          before { manifest_hash.merge!('releases' => []) }
          before { manifest_hash.merge!('release' => {}) }

          it 'raises an error' do
            expect {
              deployment
            }.to raise_error(/use one of the two/)
          end
        end

        context "when neither 'releases' or 'release' section is specified" do
          before { manifest_hash.delete('releases') }
          before { manifest_hash.delete('release') }

          it 'raises an error' do
            expect {
              deployment
            }.to raise_error(
              ValidationMissingField,
              /Required property `releases' was not specified in object .+/,
            )
          end
        end
      end

      describe 'compilation key' do
        context 'when compilation section is specified' do
          before { cloud_config_hash.merge!('compilation' => { 'foo' => 'bar' }) }

          it 'delegates parsing to CompilationConfig' do
            compilation = instance_double('Bosh::Director::DeploymentPlan::CompilationConfig')

            expect(DeploymentPlan::CompilationConfig).to receive(:new).
              with(be_a(DeploymentPlan::Planner), 'foo' => 'bar').
              and_return(compilation)

            expect(deployment.compilation).to eq(compilation)
          end
        end

        context 'when compilation section is not specified' do
          before { cloud_config_hash.delete('compilation') }

          it 'raises an error' do
            expect {
              deployment
            }.to raise_error(
              ValidationMissingField,
              /Required property `compilation' was not specified in object .+/,
            )
          end
        end
      end

      describe 'update key' do
        context 'when update section is specified' do
          before { manifest_hash.merge!('update' => { 'foo' => 'bar' }) }

          it 'delegates parsing to UpdateConfig' do
            update = instance_double('Bosh::Director::DeploymentPlan::UpdateConfig')

            expect(DeploymentPlan::UpdateConfig).to receive(:new).
              with('foo' => 'bar').
              and_return(update)

            expect(deployment.update).to eq(update)
          end
        end

        context 'when update section is not specified' do
          before { manifest_hash.delete('update') }

          it 'raises an error' do
            expect {
              deployment
            }.to raise_error(
              ValidationMissingField,
              /Required property `update' was not specified in object .+/,
            )
          end
        end
      end

      describe 'networks key' do
        context 'when there is at least one network' do
          context 'when network type is not specified' do
            before do
              cloud_config_hash.merge!(
                'networks' => [{
                    'name' => 'a',
                    'subnets' => [],
                  }])
            end

            it 'should create manual network by default' do
              expect(deployment.networks.count).to eq(1)
              expect(deployment.networks.first).to be_a(DeploymentPlan::ManualNetwork)
              expect(deployment.networks.first.name).to eq('a')
            end

            it 'allows to look up network by name' do
              expect(deployment.network('a')).to be_a(DeploymentPlan::ManualNetwork)
              expect(deployment.network('b')).to be_nil
            end
          end

          context 'when network type is manual'
          context 'when network type is dynamic'
          context 'when network type is vip'
          context 'when network type is unknown'

          context 'when more than one network have same canonical name' do
            before do
              cloud_config_hash['networks'] = [
                { 'name' => 'bar', 'subnets' => [] },
                { 'name' => 'Bar', 'subnets' => [] },
              ]
            end

            it 'raises an error' do
              expect {
                deployment
              }.to raise_error(
                DeploymentCanonicalNetworkNameTaken,
                "Invalid network name `Bar', canonical name already taken",
              )
            end
          end
        end

        context 'when 0 networks are specified' do
          before { cloud_config_hash.merge!('networks' => []) }

          it 'raises an error because deployment must have at least one network' do
            expect {
              deployment
            }.to raise_error(DeploymentNoNetworks, 'No networks specified')
          end
        end

        context 'when networks key is not specified' do
          before { cloud_config_hash.delete('networks') }

          it 'raises an error because deployment must have at least one network' do
            expect {
              deployment
            }.to raise_error(
              ValidationMissingField,
              /Required property `networks' was not specified in object .+/,
            )
          end
        end
      end

      describe 'resource_pools key' do
        context 'when there is at least one resource_pool' do
          context 'when each resource pool has a unique name' do
            before do
              cloud_config_hash['resource_pools'] = [
                Bosh::Spec::Deployments.resource_pool.merge('name' => 'rp1-name'),
                Bosh::Spec::Deployments.resource_pool.merge('name' => 'rp2-name')
              ]
            end

            it 'creates ResourcePools for each entry' do
              expect(deployment.resource_pools.map(&:class)).to eq([DeploymentPlan::ResourcePool, DeploymentPlan::ResourcePool])
              expect(deployment.resource_pools.map(&:name)).to eq(['rp1-name', 'rp2-name'])
            end

            it 'allows to look up resource_pool by name' do
              expect(deployment.resource_pool('rp1-name').name).to eq('rp1-name')
              expect(deployment.resource_pool('rp2-name').name).to eq('rp2-name')
            end
          end

          context 'when more than one resource pool have same name' do
            before do
              cloud_config_hash['resource_pools'] = [
                  Bosh::Spec::Deployments.resource_pool.merge({ 'name' => 'same-name' }),
                  Bosh::Spec::Deployments.resource_pool.merge({ 'name' => 'same-name' })
              ]
            end

            it 'raises an error' do
              expect {
                deployment
              }.to raise_error(
                DeploymentDuplicateResourcePoolName,
                "Duplicate resource pool name `same-name'",
              )
            end
          end
        end
      end

      describe 'disk_pools key' do
        context 'when there is at least one disk_pool' do
          context 'when each resource pool has a unique name' do
            before do
              cloud_config_hash['disk_pools'] = [
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'dk1-name' }),
                Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'dk2-name' })
              ]
            end

            it 'creates DiskPools for each entry' do
              expect(deployment.disk_pools.map(&:class)).to eq([DeploymentPlan::DiskPool, DeploymentPlan::DiskPool])
              expect(deployment.disk_pools.map(&:name)).to eq(['dk1-name', 'dk2-name'])
            end

            it 'allows to look up disk_pool by name' do
              expect(deployment.disk_pool('dk1-name').name).to eq('dk1-name')
              expect(deployment.disk_pool('dk2-name').name).to eq('dk2-name')
            end
          end

          context 'when more than one disk pool have same name' do
            before do
              cloud_config_hash['disk_pools'] = [
                  Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'same-name' }),
                  Bosh::Spec::Deployments.disk_pool.merge({ 'name' => 'same-name' })
              ]
            end

            it 'raises an error' do
              expect {
                deployment
              }.to raise_error(
                DeploymentDuplicateDiskPoolName,
                "Duplicate disk pool name `same-name'",
              )
            end
          end
        end
      end

      describe 'jobs key' do
        context 'when there is at least one job' do
          before { manifest_hash.merge!('jobs' => []) }

          let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

          context 'when job names are unique' do
            before do
              manifest_hash.merge!('jobs' => [
                { 'name' => 'job1-name' },
                { 'name' => 'job2-name' },
              ])
            end

            let(:job1) do
              instance_double('Bosh::Director::DeploymentPlan::Job', {
                name: 'job1-name',
                canonical_name: 'job1-canonical-name',
              })
            end

            let(:job2) do
              instance_double('Bosh::Director::DeploymentPlan::Job', {
                name: 'job2-name',
                canonical_name: 'job2-canonical-name',
              })
            end

            it 'delegates to Job to parse job specs' do
              expect(DeploymentPlan::Job).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'job1-name'}, event_log, logger).
                and_return(job1)

              expect(DeploymentPlan::Job).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'job2-name'}, event_log, logger).
                and_return(job2)

              expect(deployment.jobs).to eq([job1, job2])
            end

            it 'allows to look up job by name' do
              allow(DeploymentPlan::Job).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'job1-name'}, event_log, logger).
                and_return(job1)

              allow(DeploymentPlan::Job).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'job2-name'}, event_log, logger).
                and_return(job2)

              expect(deployment.job('job1-name')).to eq(job1)
              expect(deployment.job('job2-name')).to eq(job2)
            end
          end

          context 'when more than one job have same canonical name' do
            before do
              manifest_hash.merge!('jobs' => [
                { 'name' => 'job1-name' },
                { 'name' => 'job2-name' },
              ])
            end

            let(:job1) do
              instance_double('Bosh::Director::DeploymentPlan::Job', {
                name: 'job1-name',
                canonical_name: 'same-canonical-name',
              })
            end

            let(:job2) do
              instance_double('Bosh::Director::DeploymentPlan::Job', {
                name: 'job2-name',
                canonical_name: 'same-canonical-name',
              })
            end

            it 'raises an error' do
              allow(DeploymentPlan::Job).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'job1-name'}, event_log, logger).
                and_return(job1)

              allow(DeploymentPlan::Job).to receive(:parse).
                with(be_a(DeploymentPlan::Planner), {'name' => 'job2-name'}, event_log, logger).
                and_return(job2)

              expect {
                deployment
              }.to raise_error(
                DeploymentCanonicalJobNameTaken,
                "Invalid job name `job2-name', canonical name already taken",
              )
            end
          end
        end

        context 'when there are no jobs' do
          before { manifest_hash.merge!('jobs' => []) }

          it 'parses jobs and return empty array' do
            expect(deployment.jobs).to eq([])
          end
        end

        context 'when jobs key is not specified' do
          before { manifest_hash.delete('jobs') }

          it 'parses jobs and return empty array' do
            expect(deployment.jobs).to eq([])
          end
        end
      end

      describe 'job_rename option' do
        context 'when old_name from job_rename option is referencing a job in jobs section' do
          before { manifest_hash.merge!('jobs' => [{'name' => 'job-old-name'}]) }

          let(:job) do
            instance_double('Bosh::Director::DeploymentPlan::Job', {
              name: 'job-old-name',
              canonical_name: 'job-canonical-name',
            })
          end

          it 'raises an error because only new_name should reference a job' do
            allow(DeploymentPlan::Job).to receive(:parse).
              with(be_a(DeploymentPlan::Planner), {'name' => 'job-old-name'}, event_log, logger).
              and_return(job)

            options = {
              'job_rename' => {
                'old_name' => 'job-old-name',
                'new_name' => 'job-new-name',
              },
            }

            expect {
              subject.parse(planner_attributes, manifest_hash, cloud_config, deployment_model, options)
            }.to raise_error(
              DeploymentRenamedJobNameStillUsed,
              "Renamed job `job-old-name' is still referenced in deployment manifest",
            )
          end
        end
      end
    end
  end
end
