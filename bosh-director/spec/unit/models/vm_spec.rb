require 'spec_helper'
require 'bosh/director/models/ip_address'

module Bosh::Director::Models
  describe Vm do
    subject do
      described_class.make
    end

    before do
      subject.apply_spec=({
        'resource_pool' =>
          {'name' => 'a',
            'cloud_properties' => {},
            'stemcell' => {
              'name' => 'ubuntu-stemcell',
              'version' => '1'
            }
          }
      })
    end

    context '#apply_spec' do
      it 'should have vm_type' do
        expect(subject.apply_spec['vm_type']).to eq({'name' => 'a', 'cloud_properties' => {}})
      end

      it 'should have stemcell' do
        expect(subject.apply_spec['stemcell']).to eq({
          'alias' => 'a',
          'name' => 'ubuntu-stemcell',
          'version' => '1'
        })
      end
    end

  end
end
