require 'rspec'
require 'bosh/template/manual_link_dns_encoder'


module Bosh
  module Template
    describe ManualLinkDnsEncoder do
      subject(:encoder) { described_class.new('manual-link') }
      it 'should always return the same thing' do
        expect(subject.encode_query('something')).to eq('manual-link')
        expect(subject.encode_query({'actually' => 'anything'})).to eq('manual-link')
      end
    end
  end
end


