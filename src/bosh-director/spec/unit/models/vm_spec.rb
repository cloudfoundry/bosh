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
  end
end
