module VSphereCloud
  class VMAttributeManager
    def initialize(custom_fields_manager, logger)
      @custom_fields_manager = custom_fields_manager
      @logger = logger
    end

    def find_by_name(name)
      @custom_fields_manager.field.find { |f| f.name == name }
    end

    def create(name)
      @logger.debug("Creating DRS rule attribute: #{name}")
      @custom_fields_manager.add_field_definition(
        name,
        VimSdk::Vim::VirtualMachine,
        policy,
        policy
      )
    end

    def delete(name)
      @logger.debug("Deleting DRS rule attribute: #{name}")
      custom_field = find_by_name(name)
      @custom_fields_manager.remove_field_definition(custom_field.key) if custom_field
    end

    private

    def policy
      policy = VimSdk::Vim::PrivilegePolicyDef.new
      policy.create_privilege = 'InventoryService.Tagging.CreateTag'
      policy.delete_privilege = 'InventoryService.Tagging.DeleteTag'
      policy.read_privilege = 'System.Read'
      policy.update_privilege = 'InventoryService.Tagging.EditTag'

      policy
    end
  end
end
