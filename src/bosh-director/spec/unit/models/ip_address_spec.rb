require 'spec_helper'
require 'bosh/director/models/ip_address'

module Bosh::Director::Models
  describe IpAddress do
    subject do
      described_class.make(
        instance: instance,
        network_name: 'foonetwork',
        address: NetAddr::CIDR.create('10.10.0.1').to_i,
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
        invalid_ip.address = nil
        expect {
          invalid_ip.save
        }.to raise_error /address presence/

        invalid_ip.address = NetAddr::CIDR.create('10.10.0.1').to_i
        expect {
          invalid_ip.save
        }.not_to raise_error
      end
    end
  end
end
