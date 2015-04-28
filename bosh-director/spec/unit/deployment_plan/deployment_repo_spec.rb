require 'spec_helper'

module Bosh
  module Director
    describe DeploymentPlan::DeploymentRepo do
      subject { DeploymentPlan::DeploymentRepo.new(canonicalizer) }
      let(:canonicalizer) { Class.new { include Bosh::Director::DnsHelper }.new }

      describe '.find_or_create_by_name' do
        it 'all happens in a transaction' do
          skip "probably a better solution is to put canonical_name in the db and enforce this there"
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
                  'Invalid deployment name `Existing\', canonical name already taken (`existing\')'
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
      end
    end
  end
end
