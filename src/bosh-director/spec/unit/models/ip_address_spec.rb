require 'spec_helper'
require 'bosh/director/models/ip_address'

module Bosh::Director::Models
  describe IpAddress do
    subject do
      described_class.make(
        instance: instance,
        network_name: 'foonetwork',
        address_str: NetAddr::IPv4.parse('10.10.0.1').addr.to_s,
        static: true,
        vm: vm
      )
    end
    let(:instance) {Instance.make(job: 'foojob', index: 1, deployment: deployment)}
    let(:vm) { Vm.make(instance: instance) }
    let(:deployment) {Deployment.make(name: 'foodeployment')}

    context '#info' do
      it 'should display debugging information (job, index, network name and ip address)' do
        results = subject.info

        expect(results).to eq('foodeployment.foojob/1 - foonetwork - 10.10.0.1 (static)')
      end
    end

    context 'validations' do
      let(:ip) {IpAddress.make}

      it 'be valid with just an orphaned_vm_id' do
        ip.instance_id = nil
        ip.vm_id = nil
        ip.orphaned_vm_id = 111

        expect { ip.save }.not_to raise_error
      end

      it 'be valid with just an instance_id' do
        ip.vm_id = nil

        expect { ip.save }.not_to raise_error
      end

      it 'should require ip address' do
        ip.address_str = ""
        expect { ip.save }.to raise_error /address_str presence/

        ip.address_str = NetAddr::IPv4.parse('10.10.0.1').addr.to_s
        expect { ip.save }.not_to raise_error
      end

      it 'must have either an instance_id ord orphaned_vm_id' do
        ip.instance_id = nil
        ip.vm_id = nil
        ip.orphaned_vm_id = nil

        expect { ip.save }.to raise_error('No instance or orphaned VM associated with IP')
      end

      it 'cannot have both instance_id and orphaned_vm_id' do
        ip.instance_id = instance.id
        ip.vm_id = nil
        ip.orphaned_vm_id = 111

        expect { ip.save }.to raise_error('IP address cannot have both instance id and orphaned VM id')
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
