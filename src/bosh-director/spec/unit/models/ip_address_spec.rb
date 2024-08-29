require 'spec_helper'
require 'bosh/director/models/ip_address'
require 'ipaddr'

module Bosh::Director::Models
  describe IpAddress do
    subject(:ip_address) do
      IpAddress.new(instance: instance,
                    network_name: 'foonetwork',
                    address_str: IPAddr.new('10.10.0.1').to_i.to_s,
                    task_id: 'fake-task-id',
                    static: true,
                    vm: vm)
    end
    let(:instance) { FactoryBot.create(:models_instance, job: 'foojob', index: 1, deployment: deployment) }
    let(:vm) { FactoryBot.create(:models_vm, instance: instance) }
    let(:deployment) { FactoryBot.create(:models_deployment, name: 'foodeployment') }

    context '#info' do
      it 'should display debugging information (job, index, network name and ip address)' do
        expect(ip_address.info).to eq('foodeployment.foojob/1 - foonetwork - 10.10.0.1 (static)')
      end
    end

    context 'validations' do
      it 'be valid with just an orphaned_vm_id' do
        ip_address.instance_id = nil
        ip_address.vm_id = nil
        ip_address.orphaned_vm_id = 111

        expect { ip_address.save }.not_to raise_error
      end

      it 'be valid with just an instance_id' do
        ip_address.vm_id = nil

        expect { ip_address.save }.not_to raise_error
      end

      it 'should require ip address' do
        ip_address.address_str = ""
        expect { ip_address.save }.to raise_error /address_str presence/

        ip_address.address_str = IPAddr.new('10.10.0.1').to_i.to_s
        expect { ip_address.save }.not_to raise_error
      end

      it 'must have either an instance_id ord orphaned_vm_id' do
        ip_address.instance_id = nil
        ip_address.vm_id = nil
        ip_address.orphaned_vm_id = nil

        expect { ip_address.save }.to raise_error('No instance or orphaned VM associated with IP')
      end

      it 'cannot have both instance_id and orphaned_vm_id' do
        ip_address.instance_id = instance.id
        ip_address.vm_id = nil
        ip_address.orphaned_vm_id = 111

        expect { ip_address.save }.to raise_error('IP address cannot have both instance id and orphaned VM id')
      end
    end

    describe '#address' do
      it 'returns address in int form from address str' do
        expect(ip_address.address).to eq(168427521)
      end

      it 'raises an error when the address is an empty string' do
        ip_address.address_str = ""
        expect { ip_address.address }.to raise_error(/Unexpected address/)
      end

      it 'raises an error when the address is a string that does not contain an integer' do
        ip_address.address_str = "168427521a"
        expect { ip_address.address }.to raise_error(/Unexpected address '168427521a'/)
      end

      it 'raises an error when the address is padded' do
        ip_address.address_str = "  168427521  "
        expect { ip_address.address }.to raise_error(/Unexpected address '  168427521  '/)
      end
    end
  end
end
