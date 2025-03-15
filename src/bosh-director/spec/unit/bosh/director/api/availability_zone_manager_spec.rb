require 'spec_helper'

module Bosh::Director
  describe Api::AvailabilityZoneManager do
    subject { described_class.new }

    describe '#is_az_valid?' do
      context 'when the az being checked exists' do
        before do
          Models::LocalDnsEncodedAz.create(name: 'z1')
        end

        it 'returns true' do
          expect(subject.is_az_valid?('z1')).to be_truthy
        end
      end

      context 'when the az being checked does not exist' do
        it 'returns false' do
          expect(subject.is_az_valid?'z1').to be_falsey
        end
      end
    end
  end
end
