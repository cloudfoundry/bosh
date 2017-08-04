require 'spec_helper'
require 'bosh/director/models/vm'

module Bosh::Director::Models
  describe Vm do
    let!(:instance) { BD::Models::Instance.make }

    it 'has a many-to-one relationship to instances' do
      described_class.make(instance_id: instance.id, id: 1)
      described_class.make(instance_id: instance.id, id: 2)

      expect(described_class.find(id: 1).instance).to eq(instance)
      expect(described_class.find(id: 2).instance).to eq(instance)
    end

    describe '#before_create' do
      it 'should set created_at' do
        vm = described_class.make(instance_id: instance.id, id: 1)
        expect(vm.created_at).not_to be_nil
      end
    end
  end
end
