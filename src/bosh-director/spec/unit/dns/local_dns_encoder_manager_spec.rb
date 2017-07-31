require 'spec_helper'

module Bosh::Director
  describe LocalDnsEncoderManager do
    subject { described_class }

    describe '.persist_az_names' do
      it 'saves new AZs' do
        subject.persist_az_names(['zone1', 'zone2'])
        expect(Models::LocalDnsEncodedAz.all.count).to eq 2
        expect(Models::LocalDnsEncodedAz.all[0].name).to eq 'zone1'
        expect(Models::LocalDnsEncodedAz.all[0].id).to eq 1
        expect(Models::LocalDnsEncodedAz.all[1].name).to eq 'zone2'
        expect(Models::LocalDnsEncodedAz.all[1].id).to eq 2
      end

      it 'saves new AZs only if unique' do
        subject.persist_az_names(['zone1', 'zone2', 'zone1'])
        subject.persist_az_names(['zone1'])
        subject.persist_az_names(['zone2'])

        expect(Models::LocalDnsEncodedAz.all.count).to eq 2
        expect(Models::LocalDnsEncodedAz.all[0].name).to eq 'zone1'
        expect(Models::LocalDnsEncodedAz.all[0].id).to eq 1
        expect(Models::LocalDnsEncodedAz.all[1].name).to eq 'zone2'
        expect(Models::LocalDnsEncodedAz.all[1].id).to eq 2
      end
    end

    describe '.create_dns_encoder' do
      before do
        Models::LocalDnsEncodedAz.create(name: 'az1')
      end

      it 'should create a dns encoder that uses the current set of azs' do
        encoder = subject.create_dns_encoder
        expect(encoder.id_for_az('az1')).to eq('1')
      end
    end

    describe '.new_encoder_with_updated_index' do
      before do
        Models::LocalDnsEncodedAz.create(name: 'az1')
      end

      it 'returns a dns encoder that includes the provided azs' do
        encoder = subject.new_encoder_with_updated_index(['az2'])
        expect(encoder.id_for_az('az2')).to eq('2')
      end
    end
  end
end
