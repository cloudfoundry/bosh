require 'spec_helper'

module Bosh::Director
  describe LocalDnsEncoder do
    subject(:local_dns_encoder) { described_class.new() }

    describe '#az' do
      it 'should encode auto-incrementing ids for azs' do
        id1 = local_dns_encoder.encode_az('az1')
        id2 = local_dns_encoder.encode_az('az2')
        id3 = local_dns_encoder.encode_az('az3')

        expect(id1).to equal(1)
        expect(id2).to equal(2)
        expect(id3).to equal(3)
      end

      it 'should consistently encode the ids of the same az' do
        id1a = local_dns_encoder.encode_az('az1')
        id1b = local_dns_encoder.encode_az('az1')

        expect(id1a).to equal(1)
        expect(id1b).to equal(1)
      end

      it 'should cache lookups' do
        # TODO reconsider a better way to test this (avoid a not test)
        expect(Models::LocalDnsEncodedAz).to_not receive(:where)

        id1a = local_dns_encoder.encode_az('az1')
        id1b = local_dns_encoder.encode_az('az1')

        expect(id1a).to equal(1)
        expect(id1b).to equal(1)
      end

      context 'existing encoded azs' do
        before do
          Models::LocalDnsEncodedAz.unrestrict_primary_key
        end

        after do
          Models::LocalDnsEncodedAz.restrict_primary_key
        end

        it 'should return the existing id' do
          Models::LocalDnsEncodedAz.create(id: 1234, name: 'az1')

          id = local_dns_encoder.encode_az('az1')
          expect(id).to equal(1234)
        end
      end
    end
  end
end
