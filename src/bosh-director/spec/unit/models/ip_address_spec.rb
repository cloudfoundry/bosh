require 'spec_helper'
require 'bosh/director/models/ip_address'

module Bosh::Director::Models
  describe IpAddress do
    subject do
      described_class.make(
        instance: instance,
        network_name: 'foonetwork',
        address_str: NetAddr::CIDR.create('10.10.0.1').to_i.to_s,
        static: true
      )
    end
    let(:instance) {Instance.make(job: 'foojob', index: 1, deployment: deployment)}
    let(:deployment) {Deployment.make(name: 'foodeployment')}

    context '#info' do
      it 'should display debugging information (job, index, network name and ip address)' do
        results = subject.info

        expect(results).to eq('foodeployment.foojob/1 - foonetwork - 10.10.0.1 (static)')
      end
    end

    context 'validations' do
      it 'should require ip address' do
        invalid_ip = IpAddress.make

        invalid_ip.address_str = ""
        expect {
          invalid_ip.save
        }.to raise_error /address_str presence/

        invalid_ip.address_str = NetAddr::CIDR.create('10.10.0.1').to_i.to_s
        expect {
          invalid_ip.save
        }.not_to raise_error
      end
    end

    describe '#address' do
      it 'returns address in int form from address str' do
        expect(subject.address).to eq(168427521)
      end

      it 'raises an error when the address is an empty string' do
        invalid_ip = IpAddress.make
        invalid_ip.address_str = ""
        expect { invalid_ip.address }.to raise_error(/Unexpected address/)
      end

      it 'raises an error when the address is a string that does not contain an integer' do
        invalid_ip = IpAddress.make
        invalid_ip.address_str = "168427521a"
        expect { invalid_ip.address }.to raise_error(/Unexpected address '168427521a'/)
      end

      it 'raises an error when the address is padded' do
        invalid_ip = IpAddress.make
        invalid_ip.address_str = "  168427521  "
        expect { invalid_ip.address }.to raise_error(/Unexpected address '  168427521  '/)
      end
    end
  end
end
