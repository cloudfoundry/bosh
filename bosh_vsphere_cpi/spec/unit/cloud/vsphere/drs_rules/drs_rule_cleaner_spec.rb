require 'cloud/vsphere/drs_rules/drs_rule_cleaner'

describe VSphereCloud::DrsRuleCleaner do
  subject(:drs_rule_cleaner) { described_class.new(cloud_searcher, custom_fields_manager, logger) }
  let(:cloud_searcher) { instance_double('VSphereCloud::CloudSearcher') }
  before do
    allow(cloud_searcher).to receive(:has_managed_object_with_attribute?).
      with(VimSdk::Vim::VirtualMachine, 42).
      and_return(has_tagged_vms)
  end
  let(:has_tagged_vms) { false }

  let(:custom_fields_manager) { instance_double('VimSdk::Vim::CustomFieldsManager') }
  before do
    allow(VSphereCloud::VMAttributeManager).to receive(:new).
      with(custom_fields_manager, logger).
      and_return(vm_attribute_manager)
  end

  let(:vm_attribute_manager) { instance_double('VSphereCloud::VMAttributeManager') }
  before do
    allow(vm_attribute_manager).to receive(:find_by_name).with('drs_rule').and_return(custom_attribute)
  end
  let(:custom_attribute) { double(:custom_attribute, key: 42) }

  let(:drs_lock) { instance_double('VSphereCloud::DrsLock') }
  before do
    allow(VSphereCloud::DrsLock).to receive(:new).and_return(drs_lock)
  end

  let(:logger) { instance_double('Logger', info: nil) }

  describe '#clean' do
    context 'when there are tagged vms' do
      let(:has_tagged_vms) { true }

      it 'does not remove the custom attribute with the lock' do
        expect(drs_lock).to receive(:with_drs_lock).and_yield
        expect(vm_attribute_manager).to_not receive(:delete)
        drs_rule_cleaner.clean
      end
    end

    context 'when there are no tagged vms' do
      let(:fields) { [existing_field] }
      let(:has_tagged_vms) { false }

      it 'removes the custom attribute with the lock' do
        expect(drs_lock).to receive(:with_drs_lock).and_yield
        expect(vm_attribute_manager).to receive(:delete).with('drs_rule')
        drs_rule_cleaner.clean
      end
    end
  end
end
