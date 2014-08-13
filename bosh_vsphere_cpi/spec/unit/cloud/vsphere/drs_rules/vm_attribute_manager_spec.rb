require 'cloud/vsphere/drs_rules/vm_attribute_manager'

describe VSphereCloud::VMAttributeManager do
  subject(:vm_attribute_manager) { described_class.new(custom_fields_manager) }
  let(:custom_fields_manager) { instance_double('VimSdk::Vim::CustomFieldsManager') }
  before do
    allow(custom_fields_manager).to receive(:field).and_return(
      [
        field_matching_field,
        double(:field_non_matching_field, name: 'fake-non-matching-field', key: 99)
      ]
    )
  end

  let(:field_matching_field) { double(:field_matching_field, name: 'fake-matching-field', key: 42) }

  describe 'find_by_name' do
    it 'returns the field with the specified name' do
      expect(vm_attribute_manager.find_by_name('fake-matching-field')).to eq(field_matching_field)
    end
  end

  describe 'create' do
    it 'creates a field definition' do
      expect(custom_fields_manager).to receive(:add_field_definition) do |name, type, field_definition_policy, field_policy|
        expect(name).to eq('fake-field-name')
        expect(type).to be(VimSdk::Vim::VirtualMachine)

        [field_definition_policy, field_policy].each do |policy|
          expect(policy.create_privilege).to eq('InventoryService.Tagging.CreateTag')
          expect(policy.delete_privilege).to eq('InventoryService.Tagging.DeleteTag')
          expect(policy.read_privilege).to eq('System.Read')
          expect(policy.update_privilege).to eq('InventoryService.Tagging.EditTag')
        end
      end

      vm_attribute_manager.create('fake-field-name')
    end
  end

  describe 'delete' do
    context 'when field exist' do
      it 'deletes the field' do
        expect(custom_fields_manager).to receive(:remove_field_definition).with(42)
        vm_attribute_manager.delete('fake-matching-field')
      end
    end
    context 'when field does not exist' do
      it 'does not delete the field' do
        expect(custom_fields_manager).to_not receive(:remove_field_definition)
        vm_attribute_manager.delete('fake-non-existing-field')
      end
    end
  end
end
