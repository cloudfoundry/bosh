require 'spec_helper'

module Bosh
  module Director
    describe DeploymentPlan::DeploymentRepo do
      subject { DeploymentPlan::DeploymentRepo.new }

      before do
        Bosh::Director::Models::DirectorAttribute.make(name: 'uuid', value: 'fake-director-uuid')
      end

      describe '.find_or_create_by_name' do
        it 'all happens in a transaction' do
          skip 'probably a better solution is to put canonical_name in the db and enforce this there'
        end

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
            context 'and there is at least one scope in common between the existing deployment and provided scopes' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create(name: 'existing', teams: 'production')

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => %w(bosh.teams.production.admin bosh.teams.dev.admin)})
                ).to eq(existing)
              end
            end

            context 'and provided scopes are the same as teams on the existing deployment' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create(name: 'existing', teams: 'production')

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => ['bosh.teams.production.admin']})
                ).to eq(existing)
              end
            end

            context 'and provided scope is bosh.admin' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create(name: 'existing', teams: 'production')

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => ['bosh.admin']})
                ).to eq(existing)
              end
            end

            context 'and provided scope is bosh.<DIRECTOR-UUID>.admin' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create(name: 'existing', teams: 'production')

                expect(
                  subject.find_or_create_by_name('existing', {'scopes' => ['bosh.fake-director-uuid.admin']})
                ).to eq(existing)
              end
            end

            context 'and provided scopes contains one of the deployment teams' do
              it 'should not create a new deployment' do
                existing = Models::Deployment.create(name: 'existing', teams: 'production,dev')

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

              expect(Models::Deployment.filter(name: 'new', teams: 'production,dev').count).to eq(1)
            end
          end
        end
      end
    end
  end
end
