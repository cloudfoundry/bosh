require 'spec_helper'

shared_examples 'an instance group' do
  it { is_expected.to respond_to(:lifecycle).with(0).arguments }
  it { is_expected.to respond_to(:has_availability_zone?).with(1).arguments }
  it { is_expected.to respond_to(:has_os?).with(1).arguments }
  it { is_expected.to respond_to(:has_job?).with(2).arguments }
  it { is_expected.to respond_to(:name).with(0).arguments }
  it { is_expected.to respond_to(:network_present?).with(1).arguments }
end

module Bosh::Director
  describe InstanceGroupConfig do
    it_behaves_like 'an instance group'

    subject do
      InstanceGroupConfig.new(instance_group, stemcells)
    end

    let(:instance_group) do
      {
        'lifecycle' => 'errand',
        'name' => 'test_instance_group',
        'azs' => ['az1'],
        'stemcell' => 'default',
        'jobs' => [
          {
            'release' => 'test_release',
            'name' => 'test_job',
          },
        ],
        'networks' => [
          {
            'name' => 'default',
          },
        ],
      }
    end

    let(:stemcells) do
      [
        {
          'alias' => 'default',
          'os' => 'ubuntu-trusty',
          'version' => 1234,
        },
        {
          'alias' => 'xenial',
          'os' => 'ubuntu-xenial',
          'version' => 5678,
        },
      ]
    end

    describe :lifecycle do
      it 'returns the lifecycle' do
        expect(subject.lifecycle).to eq('errand')
      end
    end

    describe :name do
      it 'returns the instance group name' do
        expect(subject.name).to eq('test_instance_group')
      end
    end

    describe :has_availability_zone? do
      context 'when availability zone exists' do
        it 'returns true' do
          expect(subject.has_availability_zone?('az1')).to be true
        end
      end

      context 'when availability zone does not exist' do
        it 'returns false' do
          expect(subject.has_availability_zone?('az2')).to be false
        end
      end
    end

    describe :has_os? do
      context 'when stemcell with operating system exists' do
        it 'returns true' do
          expect(subject.has_os?('ubuntu-trusty')).to be true
        end
      end

      context 'when stemcell with operating system does not match stemcell alias' do
        it 'returns false' do
          expect(subject.has_os?('ubuntu-xenial')).to be false
        end
      end
    end

    describe :has_job? do
      context 'when instance group has job' do
        it 'returns true' do
          expect(subject.has_job?('test_job', 'test_release')).to be true
        end
      end

      context 'when instance group has job with different name' do
        it 'returns false' do
          expect(subject.has_job?('different_job', 'test_release')).to be false
        end
      end

      context 'when instance group hs different release' do
        it 'returns false' do
          expect(subject.has_job?('test_job', 'different_release')).to be false
        end
      end
    end

    describe :network_present? do
      context 'when network exists' do
        it 'returns true' do
          expect(subject.network_present?('default')).to be true
        end
      end

      context 'when network does not match by name' do
        it 'returns false' do
          expect(subject.network_present?('manual')).to be false
        end
      end
    end
  end
end
