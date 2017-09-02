require 'spec_helper'

module Bosh::Director
  describe Errand::InstanceMatcher do
    subject(:matcher) { Errand::InstanceMatcher.new(requested) }
    let(:instances_in_group) { [] }
    context 'when no requested instances are supplied' do
      let(:requested) { [] }
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name') }

      it 'matches always' do
        expect(matcher.matches?(instance, instances_in_group)).to eq(true)
      end

      it 'has no unmatched criteria' do
        expect(matcher.unmatched_criteria).to eq([])
      end
    end

    context 'when matching by group name' do
      let(:requested) { [{'group' => 'group-name'}] }
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name') }

      context 'when the instance matches' do
        it 'returns true' do
          expect(matcher.matches?(instance, instances_in_group)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name'}])
          matcher.matches?(instance, instances_in_group)
          expect(matcher.unmatched_criteria).to eq([])
        end
      end

      context 'when the instance does not match' do
        let(:requested) { [{'group' => 'different-group-name'}] }
        it 'returns false' do
          expect(matcher.matches?(instance, instances_in_group)).to eq(false)
        end

        it 'reports no unmatched requests' do
          matcher.matches?(instance, instances_in_group)
          expect(matcher.unmatched_criteria).to eq([{'group' => 'different-group-name'}])
        end
      end
    end

    context 'when matching by group name and uuid' do
      let(:requested) { [{'group' => 'group-name', 'id' => '123abc'}] }
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }

      context 'when the instance does not match' do
        let(:requested) { [{'group' => 'group-name', 'id' => '123def'}] }

        it 'returns true' do
          expect(matcher.matches?(instance, instances_in_group)).to eq(false)
        end

        it 'reports unmatched requests' do
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => '123def'}])
          matcher.matches?(instance, instances_in_group)
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => '123def'}])
        end
      end

      context 'when the instance matches' do
        let(:requested) { [{'group' => 'group-name', 'id' => '123abc'}] }

        it 'returns true' do
          expect(matcher.matches?(instance, instances_in_group)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => '123abc'}])
          matcher.matches?(instance, instances_in_group)
          expect(matcher.unmatched_criteria).to eq([])
        end
      end
    end

    context 'when matching by group name and index' do
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }

      context 'when the instance matches' do
        let(:requested) { [{'group' => 'group-name', 'id' => '2'}] }
        it 'returns true' do
          expect(matcher.matches?(instance, instances_in_group)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => '2'}])
          matcher.matches?(instance, instances_in_group)
          expect(matcher.unmatched_criteria).to eq([])
        end
      end

      context 'when the instance does not match' do
        let(:requested) { [{'group' => 'group-name', 'id' => '3'}] }

        it 'returns true' do
          expect(matcher.matches?(instance, instances_in_group)).to eq(false)
        end

        it 'reports unmatched requests' do
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => '3'}])
          matcher.matches?(instance, instances_in_group)
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => '3'}])
        end
      end
    end

    context 'when criteria overlap' do
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }

      context 'when the instance matches all crieterias' do
        let(:requested) { [{'group' => 'group-name', 'id' => '2'}, {'group' => 'group-name', 'id' => '123abc'}, {'group' => 'group-name'}] }

        it 'returns true' do
          expect(matcher.matches?(instance, instances_in_group)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => '2'}, {'group' => 'group-name', 'id' => '123abc'}, {'group' => 'group-name'}])
          matcher.matches?(instance, instances_in_group)
          expect(matcher.unmatched_criteria).to eq([])
        end
      end

      context 'when the instance matches some criteria' do
        let(:requested) { [{'group' => 'group-name', 'id' => '2'}, {'group' => 'group-name', 'id' => '123abc'}, {'group' => 'other-group-name'}] }

        it 'returns true' do
          expect(matcher.matches?(instance, instances_in_group)).to eq(true)
        end

        it 'reports no unmatched requests' do
          expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => '2'}, {'group' => 'group-name', 'id' => '123abc'}, {'group' => 'other-group-name'}])
          matcher.matches?(instance, instances_in_group)
          expect(matcher.unmatched_criteria).to eq([{'group' => 'other-group-name'}])
        end
      end
    end

    context 'when run against multiple instances' do
      let(:instance1) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123abc', index: 2) }
      let(:instance2) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: '123def', index: 0) }
      let(:requested) { [{'group' => 'group-name', 'id' => '2'}, {'group' => 'group-name', 'id' => '123def'}, {'group' => 'other-group-name', 'id' => 'foo'}] }

      it 'recalls all that criteria that have ever been matched by any instance' do
        expect(matcher.matches?(instance1, instances_in_group)).to eq(true)
        expect(matcher.matches?(instance2, instances_in_group)).to eq(true)
        expect(matcher.unmatched_criteria).to eq([{'group' => 'other-group-name', 'id' => 'foo'}])
      end
    end

    context 'when matching by instance-group/first' do
      let(:instance1) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: 'a', index: 2) }
      let(:instance2) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: 'b', index: 0) }
      let(:instance3) { instance_double(DeploymentPlan::Instance, job_name: 'group-name', uuid: 'c', index: 0) }
      let(:instances_in_group) { [instance3, instance1, instance2] }
      let(:requested) { [{'group' => 'group-name', 'id' => 'first'}] }

      it 'matches on the instance with the first instance sorted by uuid' do
        expect(matcher.matches?(instance1, instances_in_group)).to eq(true)
      end

      it 'does not match against the other instances in the group' do
        expect(matcher.matches?(instance2, instances_in_group)).to eq(false)
        expect(matcher.matches?(instance3, instances_in_group)).to eq(false)
      end

      it 'recalls that the criteria has been matched' do
        expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => 'first'}])
        matcher.matches?(instance2, instances_in_group)
        expect(matcher.unmatched_criteria).to eq([{'group' => 'group-name', 'id' => 'first'}])
        matcher.matches?(instance1, instances_in_group)
        expect(matcher.unmatched_criteria).to eq([])
      end
    end

    context 'with malformed filters' do
      let(:instance) { instance_double(DeploymentPlan::Instance, job_name: 'group-name') }
      let(:requested) { ['group', 7, [], nil] }

      it 'quietly does not match any instances' do
        expect(matcher.matches?(instance, instances_in_group)).to eq(false)
        expect(matcher.unmatched_criteria).to eq(['group', 7, [], nil])
      end
    end
  end
end
