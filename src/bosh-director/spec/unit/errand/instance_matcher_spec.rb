require 'spec_helper'

module Bosh::Director
  describe Errand::InstanceMatcher do
    subject(:matcher) { Errand::InstanceMatcher.new(requested) }

    context 'when no requested instances are supplied' do
      let(:requested) { [] }
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name') }

      it 'matches always' do
        expect(matcher.matches?(instance)).to eq(true)
      end

      it 'has no unmatched criteria' do
        expect(matcher.unmatched_criteria).to eq([])
      end
    end

    context 'when matching by group name' do
      let(:requested) { ['group-name'] }
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name') }

      context 'when the instance matches' do
        it 'returns true' do
          expect(matcher.matches?(instance)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq(['group-name'])
          matcher.matches?(instance)
          expect(matcher.unmatched_criteria).to eq([])
        end
      end

      context 'when the instance does not match' do
        let(:requested) { ['different-group-name'] }
        it 'returns true' do
          expect(matcher.matches?(instance)).to eq(false)
        end

        it 'reports no unmatched requests' do
          matcher.matches?(instance)
          expect(matcher.unmatched_criteria).to eq(['different-group-name'])
        end
      end
    end

    context 'when matching by group name and uuid' do
      let(:requested) { ['group-name/123abc'] }
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }

      context 'when the instance does not match' do
        let(:requested) { ['group-name/123def'] }

        it 'returns true' do
          expect(matcher.matches?(instance)).to eq(false)
        end

        it 'reports unmatched requests' do
          expect(matcher.unmatched_criteria).to eq(['group-name/123def'])
          matcher.matches?(instance)
          expect(matcher.unmatched_criteria).to eq(['group-name/123def'])
        end
      end
    end

    context 'when matching by group name and index' do
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }

      context 'when the instance matches' do
        let(:requested) { ['group-name/2'] }
        it 'returns true' do
          expect(matcher.matches?(instance)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq(['group-name/2'])
          matcher.matches?(instance)
          expect(matcher.unmatched_criteria).to eq([])
        end
      end

      context 'when the instance does not match' do
        let(:requested) { ['group-name/3'] }

        it 'returns true' do
          expect(matcher.matches?(instance)).to eq(false)
        end

        it 'reports unmatched requests' do
          expect(matcher.unmatched_criteria).to eq(['group-name/3'])
          matcher.matches?(instance)
          expect(matcher.unmatched_criteria).to eq(['group-name/3'])
        end
      end
    end

    context 'when criteria overlap' do
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }

      context 'when the instance matches all crieterias' do
        let(:requested) { ['group-name/2', 'group-name/123abc', 'group-name'] }
        it 'returns true' do
          expect(matcher.matches?(instance)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq(['group-name/2', 'group-name/123abc', 'group-name'])
          matcher.matches?(instance)
          expect(matcher.unmatched_criteria).to eq([])
        end
      end

      context 'when the instance matches some criteria' do
        let(:requested) { ['group-name/2', 'group-name/123abc', 'other-group-name'] }
        it 'returns true' do
          expect(matcher.matches?(instance)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq(['group-name/2', 'group-name/123abc', 'other-group-name'])
          matcher.matches?(instance)
          expect(matcher.unmatched_criteria).to eq(['other-group-name'])
        end
      end
    end

    context 'when run against multiple instances' do
      let(:instance1) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }
      let(:instance2) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123def', index: 0) }
      let(:requested) { ['group-name/2', 'group-name/123def', 'other-group-name/foo'] }

      it 'recalls all that criteria that have ever been matched by any instance' do
        expect(matcher.matches?(instance1)).to eq(true)
        expect(matcher.matches?(instance2)).to eq(true)
        expect(matcher.unmatched_criteria).to eq(['other-group-name/foo'])
      end
    end
  end
end
