require 'spec_helper'
require 'securerandom'

module Bosh
  module Director
    describe DeploymentPlan::DeploymentRepo do
      subject { DeploymentPlan::DeploymentRepo.new }

      before do
        FactoryBot.create(:models_director_attribute, name: 'uuid', value: 'fake-director-uuid')
      end

      it 'serializes creation of names with the same canonical form' do
        records = []
        errors = Queue.new
        store_mutex = Mutex.new
        registry_mutex = Mutex.new
        locks = {}
        allow(Lock).to receive(:new) do |name, _options|
          mutex = registry_mutex.synchronize { locks[name] ||= Mutex.new }
          Object.new.tap { |lock| lock.define_singleton_method(:lock) { |&block| mutex.synchronize(&block) } }
        end
        transactor = instance_double(Transactor)
        allow(Transactor).to receive(:new).and_return(transactor)
        allow(transactor).to receive(:retryable_transaction).and_yield
        allow(Models::Deployment).to receive(:each) do |&block|
          store_mutex.synchronize { records.dup }.each(&block)
        end
        allow(Models::Deployment).to receive(:create_with_teams) do |attributes|
          sleep(0.02)
          store_mutex.synchronize { records << Struct.new(:name).new(attributes[:name]) }
        end
        ready = Queue.new
        start = Queue.new
        threads = %w[Example example].map do |name|
          Thread.new do
            ready << true
            start.pop
            begin
              DeploymentPlan::DeploymentRepo.new.send(:create_for_attributes, name: name)
            rescue => error
              errors << error
            end
          end
        end
        2.times { ready.pop }
        2.times { start << true }
        threads.each(&:join)

        expect(records.size).to eq(1)
        expect(errors.size).to eq(1)
        expect(errors.pop).to be_a(DeploymentCanonicalNameTaken)
      end

      describe '.find_or_create_by_name' do
        context 'when a deployment with that name exists' do
          it 'loads that one' do
            existing = Models::Deployment.create(name: 'existing')
            expect(subject.find_or_create_by_name('existing')).to eq(existing)
          end
        end

        context 'when no deployment with that name exists' do
          context 'but a model with that canonical name exists' do
            it 'blows up' do
              Models::Deployment.create(name: 'existinG')
              expect {
                subject.find_or_create_by_name('Existing')
              }.to raise_error(
                DeploymentCanonicalNameTaken,
                "Invalid deployment name 'Existing', canonical name already taken ('existing')"
              )
            end
          end

          context 'and no deployment has the same canonical name' do
            it 'creates one' do
              expect {
                instance = subject.find_or_create_by_name('foo')
                expect(instance.name).to eq('foo')
              }.to change { Models::Deployment.count }
            end
          end
        end

        context 'when scopes are provided' do
          context 'and there is an existing deployment with the same name' do
            let(:prod_team) { [ FactoryBot.create(:models_team, name: 'production') ] }
            let(:prod_dev_teams) { [ FactoryBot.create(:models_team, name: 'production'), FactoryBot.create(:models_team, name: 'dev') ] }

            context 'and there is at least one scope in common between the existing deployment and provided scopes' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create_with_teams(name: 'existing', teams: prod_team)

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => %w(bosh.teams.production.admin bosh.teams.dev.admin)})
                ).to eq(existing)
              end
            end

            context 'and provided scopes are the same as teams on the existing deployment' do
              it 'should not create a new deployment' do

                existing = Models::Deployment.create_with_teams(name: 'existing', teams: prod_dev_teams)

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => ['bosh.teams.production.admin']})
                ).to eq(existing)
              end
            end

            context 'and provided scope is bosh.admin' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create_with_teams(name: 'existing', teams: prod_dev_teams)

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => ['bosh.admin']})
                ).to eq(existing)
              end
            end

            context 'and provided scope is bosh.<DIRECTOR-UUID>.admin' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create_with_teams(name: 'existing', teams: prod_dev_teams)

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => ['bosh.fake-director-uuid.admin']})
                ).to eq(existing)
              end
            end

            context 'and provided scopes contains one of the deployment teams' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create_with_teams(name: 'existing', teams: prod_dev_teams)

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => ['bosh.teams.dev.admin']})
                ).to eq(existing)
              end
            end
          end

          context 'and there is no existing deployment with the same name' do
            it 'should create a new deployment' do
              expect {
                subject.find_or_create_by_name('new', {'scopes' => ['bosh.teams.production.admin', 'bosh.teams.dev.admin']})
              }.to change { Models::Deployment.count }

              found = Models::Deployment.filter(name: 'new')
              expect(found.count).to eq(1)
              deployment = found.first
              expect(deployment.teams.map(&:name).sort).to eq(['dev','production'])
            end
          end
        end

        context 'when cloud configs and runtime configs are given' do
          it 'should persist these associations' do
            cloud_configs = [FactoryBot.create(:models_config_cloud)]
            runtime_configs = [FactoryBot.create(:models_config_runtime), FactoryBot.create(:models_config_runtime), FactoryBot.create(:models_config_runtime)]
            deployment = subject.find_or_create_by_name('foo', { 'cloud_configs' => cloud_configs,
                                                                 'runtime_configs' => runtime_configs })
            expect(deployment.cloud_configs).to eq(cloud_configs)
            expect(deployment.runtime_configs).to eq(runtime_configs)
          end
        end
      end
    end
  end
end
