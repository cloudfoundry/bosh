require 'spec_helper'

module Bosh
  module Director
    module DeploymentPlan
      describe PlannerFactory do
        subject { PlannerFactory.new(canonicalizer, deployment_manifest_migrator, deployment_repo, event_log, logger) }
        let(:deployment_repo) { DeploymentRepo.new(canonicalizer) }
        let(:canonicalizer) { Class.new { include Bosh::Director::DnsHelper }.new }
        let(:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }
        let(:deployment_manifest_migrator) { instance_double(ManifestMigrator) }
        let(:cloud_config_model) { Models::CloudConfig.make(manifest: cloud_config_hash) }
        let(:cloud_config_hash) { Bosh::Spec::Deployments.simple_cloud_config }
        let(:plan_options) { {} }
        let(:event_log_io) { StringIO.new("") }
        let(:logger_io) { StringIO.new("") }
        let(:event_log) {Bosh::Director::EventLog::Log.new(event_log_io)}
        let(:logger) do
          logger = Logging::Logger.new('PlannerFactorySpecs')
          logger.add_appenders(
            Logging.appenders.io(
              'PlannerFactorySpecs IO',
              logger_io,
              layout: Logging.layouts.pattern(:pattern => '%m\n')
            )
          )
          logger
        end

        before do
          allow(deployment_manifest_migrator).to receive(:migrate) { |deployment_manifest, cloud_config| [deployment_manifest, cloud_config.manifest] }
          upload_releases
          upload_stemcell
          configure_config
          fake_locks
        end

        describe '#planner' do
          let(:planner) do
            subject.planner(manifest_hash, cloud_config_model, plan_options)
          end

          it 'returns a planner' do
            expect(planner).to be_a(Planner)
            expect(planner.name).to eq('simple')
          end

          it 'migrates the deployment manifest to handle legacy structure' do
            allow(deployment_manifest_migrator).to receive(:migrate) do |hash, cloud_config|
              [hash.merge({'name' => 'migrated_name'}), cloud_config.manifest]
            end

            expect(planner.name).to eq('migrated_name')
          end

          describe 'attributes of the planner' do
            it 'has a backing model' do
              expect(planner.model.name).to eq('simple')
            end

            describe 'properties' do
              it 'comes from the deployment_manifest' do
                expected = {
                  'foo' => 1,
                  'bar' => { 'baz' => 2 }
                }
                manifest_hash['properties'] = expected
                expect(planner.properties).to eq(expected)
              end

              it 'has a sensible default' do
                manifest_hash.delete('properties')
                expect(planner.properties).to eq({})
              end
            end

            describe 'releases' do
              let(:manifest_hash) do
                manifest_hash = Bosh::Spec::Deployments.simple_manifest.merge(
                  'releases' => [
                    {'name' => 'bosh-release', 'version' => 1},
                    {'name' => 'bar-release', 'version' => 2},
                  ],
                )

                manifest_hash['jobs'].first['release'] = 'bosh-release'
                manifest_hash
              end

              it 'has the releases from the deployment manifest' do
                expect(planner.releases.map { |r| [r.name, r.version] }).to match_array(
                  [
                    ['bosh-release', '1'],
                    ['bar-release', '2']
                  ]
                )
              end
            end

            describe 'disk_pools' do
              let(:cloud_config_hash) do
                Bosh::Spec::Deployments.simple_cloud_config.merge(
                  {
                    'disk_pools' => [
                      {'name' => 'disk_pool1', 'disk_size' => 3000},
                      {'name' => 'disk_pool2', 'disk_size' => 1000},
                    ]
                  }
                )
              end

              it 'has disk_pools from the cloud config manifest' do
                expect(planner.disk_pools.length).to eq(2)
                expect(planner.disk_pool('disk_pool1').disk_size).to eq(3000)
                expect(planner.disk_pool('disk_pool2').disk_size).to eq(1000)
              end
            end
          end
        end

        def configure_config
          allow(Config).to receive(:dns_domain_name).and_return('some-dns-domain-name')
          allow(Config).to receive(:dns).and_return({'address' => 'foo'})
          allow(Config).to receive(:cloud).and_return(double('cloud'))
        end

        def fake_locks
          lock = instance_double('Bosh::Director::Lock')
          allow(Lock).to receive(:new).and_return(lock)
          allow(lock).to receive(:release)
          allow(lock).to receive(:lock)
        end

        def upload_releases
          manifest_hash['releases'].each do |release_entry|
            job = manifest_hash['jobs'].first
            release = Models::Release.make(name: release_entry['name'])
            template = Models::Template.make(name: job['template'], release: release)
            release_version = Models::ReleaseVersion.make(release: release, version: release_entry['version'])
            release_version.add_template(template)
          end
        end

        def upload_stemcell
          stemcell_entry = cloud_config_model.manifest['resource_pools'].first['stemcell']
          Models::Stemcell.make(name: stemcell_entry['name'], version: stemcell_entry['version'])
        end
      end
    end
  end
end
