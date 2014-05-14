require 'spec_helper'
require 'bosh/director/dns_helper'

module Bosh::Director
  module DeploymentPlan
    describe DeploymentSpecParser do
      subject(:parser) { described_class.new(event_log) }
      let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

      describe '#parse' do
        let(:deployment_spec) do
          {
            'name' => 'deployment-name',
            'releases' => [],
            'networks' => [{ 'name' => 'network-name' }],
            'compilation' => {},
            'update' => {},
            'resource_pools' => [],
          }
        end

        before { allow(CompilationConfig).to receive(:new).and_return(compilation_config) }
        let(:compilation_config) { instance_double('Bosh::Director::DeploymentPlan::CompilationConfig') }

        before { allow(UpdateConfig).to receive(:new).and_return(update_config) }
        let(:update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig') }

        before { allow(ManualNetwork).to receive(:new).and_return(network) }
        let(:network) do
          instance_double('Bosh::Director::DeploymentPlan::Network', {
            name: 'fake-network-name',
            canonical_name: 'fake-network-name',
          })
        end

        describe 'name key' do
          it 'parses name' do
            deployment_spec.merge!('name' => 'Name with spaces')
            deployment = parser.parse(deployment_spec)
            expect(deployment.name).to eq('Name with spaces')
          end

          it 'sets canonical name' do
            deployment_spec.merge!('name' => 'Name with spaces')
            deployment = parser.parse(deployment_spec)
            expect(deployment.canonical_name).to eq('namewithspaces')
          end
        end

        describe 'properties key' do
          it 'parses basic properties' do
            deployment_spec.merge!('properties' => { 'foo' => 'bar' })
            deployment = parser.parse(deployment_spec)
            expect(deployment.properties).to eq('foo' => 'bar')
          end

          it 'allows to not include properties key' do
            deployment_spec.delete('properties')
            deployment = parser.parse(deployment_spec)
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
            before { deployment_spec.merge!('release' => {'name' => 'rv-name'}) }
            before { deployment_spec.delete('releases') }

            let(:rv) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'rv-name') }

            it 'delegates to ReleaseVersion' do
              expect(ReleaseVersion).to receive(:new).
                with(be_a(Planner), 'name' => 'rv-name').
                and_return(rv)

              deployment = parser.parse(deployment_spec)
              expect(deployment.releases).to eq([rv])
            end

            it 'allows to look up release by name' do
              allow(ReleaseVersion).to receive(:new).
                with(be_a(Planner), 'name' => 'rv-name').
                and_return(rv)

              deployment = parser.parse(deployment_spec)
              expect(deployment.release('rv-name')).to eq(rv)
            end
          end

          context "when 'releases' section is specified" do
            before { deployment_spec.delete('release') }

            context 'when non-duplicate releases are included' do
              before do
                deployment_spec.merge!('releases' => [
                  {'name' => 'rv1-name'},
                  {'name' => 'rv2-name'},
                ])
              end

              let(:rv1) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'rv1-name') }
              let(:rv2) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'rv2-name') }

              it 'delegates to ReleaseVersion' do
                expect(ReleaseVersion).to receive(:new).
                  with(be_a(Planner), 'name' => 'rv1-name').
                  and_return(rv1)

                expect(ReleaseVersion).to receive(:new).
                  with(be_a(Planner), 'name' => 'rv2-name').
                  and_return(rv2)

                deployment = parser.parse(deployment_spec)
                expect(deployment.releases).to eq([rv1, rv2])
              end

              it 'allows to look up release by name' do
                allow(ReleaseVersion).to receive(:new).
                  with(be_a(Planner), 'name' => 'rv1-name').
                  and_return(rv1)

                allow(ReleaseVersion).to receive(:new).
                  with(be_a(Planner), 'name' => 'rv2-name').
                  and_return(rv2)

                deployment = parser.parse(deployment_spec)
                expect(deployment.release('rv1-name')).to eq(rv1)
                expect(deployment.release('rv2-name')).to eq(rv2)
              end
            end

            context 'when duplicate releases are included' do
              before do
                deployment_spec.merge!('releases' => [
                  {'name' => 'same-name'},
                  {'name' => 'same-name'},
                ])
              end

              let(:rv) { instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'same-name') }

              it 'raises an error' do
                allow(ReleaseVersion).to receive(:new).
                  with(be_a(Planner), 'name' => 'same-name').
                  and_return(rv)

                expect {
                  parser.parse(deployment_spec)
                }.to raise_error(/duplicate release name/i)
              end
            end
          end

          context "when both 'releases' and 'release' sections are specified" do
            before { deployment_spec.merge!('releases' => []) }
            before { deployment_spec.merge!('release' => {}) }

            it 'raises an error' do
              expect {
                parser.parse(deployment_spec)
              }.to raise_error(/use one of the two/)
            end
          end

          context "when neither 'releases' or 'release' section is specified" do
            before { deployment_spec.delete('releases') }
            before { deployment_spec.delete('release') }

            it 'raises an error' do
              expect {
                parser.parse(deployment_spec)
              }.to raise_error(
                ValidationMissingField,
                /Required property `releases' was not specified in object .+/,
              )
            end
          end
        end

        describe 'compilation key' do
          context 'when compilation section is specified' do
            before { deployment_spec.merge!('compilation' => { 'foo' => 'bar' }) }

            it 'delegates parsing to CompilationConfig' do
              compilation = instance_double('Bosh::Director::DeploymentPlan::CompilationConfig')

              expect(CompilationConfig).to receive(:new).
                with(be_a(Planner), 'foo' => 'bar').
                and_return(compilation)

              deployment = parser.parse(deployment_spec)
              expect(deployment.compilation).to eq(compilation)
            end
          end

          context 'when compilation section is not specified' do
            before { deployment_spec.delete('compilation') }

            it 'raises an error' do
              expect {
                parser.parse(deployment_spec)
              }.to raise_error(
                ValidationMissingField,
                /Required property `compilation' was not specified in object .+/,
              )
            end
          end
        end

        describe 'update key' do
          context 'when update section is specified' do
            before { deployment_spec.merge!('update' => { 'foo' => 'bar' }) }

            it 'delegates parsing to UpdateConfig' do
              update = instance_double('Bosh::Director::DeploymentPlan::UpdateConfig')

              expect(UpdateConfig).to receive(:new).
                with('foo' => 'bar').
                and_return(update)

              deployment = parser.parse(deployment_spec)
              expect(deployment.update).to eq(update)
            end
          end

          context 'when update section is not specified' do
            before { deployment_spec.delete('update') }

            it 'raises an error' do
              expect {
                parser.parse(deployment_spec)
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
              before { deployment_spec.merge!('networks' => [{ 'foo' => 'bar' }]) }

              let(:network) do
                instance_double('Bosh::Director::DeploymentPlan::Network').tap do |net|
                  allow(net).to receive(:name).and_return('fake-net-name')
                  allow(net).to receive(:canonical_name).and_return('fake-net-cname')
                end
              end

              it 'should create manual network by default' do
                expect(ManualNetwork).to receive(:new).
                  with(be_a(Planner), 'foo' => 'bar').
                  and_return(network)

                deployment = parser.parse(deployment_spec)
                expect(deployment.networks).to eq([network])
              end

              it 'allows to look up network by name' do
                allow(ManualNetwork).to receive(:new).and_return(network)
                deployment = parser.parse(deployment_spec)
                expect(deployment.network('fake-net-name')).to eq(network)
              end
            end

            context 'when network type is manual'
            context 'when network type is dynamic'
            context 'when network type is vip'
            context 'when network type is unknown'

            context 'when more than one network have same canonical name' do
              before do
                deployment_spec.merge!('networks' => [
                  { 'name' => 'bar' },
                  { 'name' => 'Bar' },
                ])
              end

              it 'raises an error' do
                allow(ManualNetwork).to receive(:new) do |_, network_spec|
                  instance_double('Bosh::Director::DeploymentPlan::Network', {
                    name: network_spec['name'],
                    canonical_name: 'same-canonical-name',
                  })
                end

                expect {
                  parser.parse(deployment_spec)
                }.to raise_error(
                  DeploymentCanonicalNetworkNameTaken,
                  "Invalid network name `Bar', canonical name already taken",
                )
              end
            end
          end

          context 'when 0 networks are specified' do
            before { deployment_spec.merge!('networks' => []) }

            it 'raises an error because deployment must have at least one network' do
              expect {
                parser.parse(deployment_spec)
              }.to raise_error(DeploymentNoNetworks, 'No networks specified')
            end
          end

          context 'when networks key is not specified' do
            before { deployment_spec.delete('networks') }

            it 'raises an error because deployment must have at least one network' do
              expect {
                parser.parse(deployment_spec)
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
                deployment_spec.merge!('resource_pools' => [
                  {'name' => 'rp1-name'},
                  {'name' => 'rp2-name'},
                ])
              end

              let(:rp1) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'rp1-name') }
              let(:rp2) { instance_double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'rp2-name') }

              it 'delegates to ResourcePool' do
                expect(ResourcePool).to receive(:new).
                  with(be_a(Planner), 'name' => 'rp1-name').
                  and_return(rp1)

                expect(ResourcePool).to receive(:new).
                  with(be_a(Planner), 'name' => 'rp2-name').
                  and_return(rp2)

                deployment = parser.parse(deployment_spec)
                expect(deployment.resource_pools).to eq([rp1, rp2])
              end

              it 'allows to look up resource_pool by name' do
                allow(ResourcePool).to receive(:new).
                  with(be_a(Planner), 'name' => 'rp1-name').
                  and_return(rp1)

                allow(ResourcePool).to receive(:new).
                  with(be_a(Planner), 'name' => 'rp2-name').
                  and_return(rp2)

                deployment = parser.parse(deployment_spec)
                expect(deployment.resource_pool('rp1-name')).to eq(rp1)
                expect(deployment.resource_pool('rp2-name')).to eq(rp2)
              end
            end

            context 'when more than one resource pool have same name' do
              before do
                deployment_spec.merge!('resource_pools' => [
                  { 'name' => 'same-name' },
                  { 'name' => 'same-name' },
                ])
              end

              it 'raises an error' do
                allow(ResourcePool).to receive(:new) do
                  instance_double('Bosh::Director::DeploymentPlan::ResourcePool', name: 'same-name')
                end

                expect {
                  parser.parse(deployment_spec)
                }.to raise_error(
                  DeploymentDuplicateResourcePoolName,
                  "Duplicate resource pool name `same-name'",
                )
              end
            end
          end
        end

        describe 'jobs key' do
          context 'when there is at least one job' do
            before { deployment_spec.merge!('jobs' => []) }

            let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

            context 'when job names are unique' do
              before do
                deployment_spec.merge!('jobs' => [
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
                expect(Job).to receive(:parse).
                  with(be_a(Planner), {'name' => 'job1-name'}, event_log).
                  and_return(job1)

                expect(Job).to receive(:parse).
                  with(be_a(Planner), {'name' => 'job2-name'}, event_log).
                  and_return(job2)

                deployment = parser.parse(deployment_spec)
                expect(deployment.jobs).to eq([job1, job2])
              end

              it 'allows to look up job by name' do
                allow(Job).to receive(:parse).
                  with(be_a(Planner), {'name' => 'job1-name'}, event_log).
                  and_return(job1)

                allow(Job).to receive(:parse).
                  with(be_a(Planner), {'name' => 'job2-name'}, event_log).
                  and_return(job2)

                deployment = parser.parse(deployment_spec)
                expect(deployment.job('job1-name')).to eq(job1)
                expect(deployment.job('job2-name')).to eq(job2)
              end
            end

            context 'when more than one job have same canonical name' do
              before do
                deployment_spec.merge!('jobs' => [
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
                allow(Job).to receive(:parse).
                  with(be_a(Planner), {'name' => 'job1-name'}, event_log).
                  and_return(job1)

                allow(Job).to receive(:parse).
                  with(be_a(Planner), {'name' => 'job2-name'}, event_log).
                  and_return(job2)

                expect {
                  parser.parse(deployment_spec)
                }.to raise_error(
                  DeploymentCanonicalJobNameTaken,
                  "Invalid job name `job2-name', canonical name already taken",
                )
              end
            end
          end

          context 'when there are no jobs' do
            before { deployment_spec.merge!('jobs' => []) }

            it 'parses jobs and return empty array' do
              deployment = parser.parse(deployment_spec)
              expect(deployment.jobs).to eq([])
            end
          end

          context 'when jobs key is not specified' do
            before { deployment_spec.delete('jobs') }

            it 'parses jobs and return empty array' do
              deployment = parser.parse(deployment_spec)
              expect(deployment.jobs).to eq([])
            end
          end
        end

        describe 'job_rename option' do
          context 'when old_name from job_rename option is referencing a job in jobs section' do
            before { deployment_spec.merge!('jobs' => [{'name' => 'job-old-name'}]) }

            let(:job) do
              instance_double('Bosh::Director::DeploymentPlan::Job', {
                name: 'job-old-name',
                canonical_name: 'job-canonical-name',
              })
            end

            it 'raises an error because only new_name should reference a job' do
              allow(Job).to receive(:parse).
                with(be_a(Planner), {'name' => 'job-old-name'}, event_log).
                and_return(job)

              options = {
                'job_rename' => {
                  'old_name' => 'job-old-name',
                  'new_name' => 'job-new-name',
                },
              }

              expect {
                parser.parse(deployment_spec, options)
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
end
