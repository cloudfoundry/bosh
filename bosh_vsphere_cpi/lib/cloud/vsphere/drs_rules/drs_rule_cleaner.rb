require 'cloud/vsphere/drs_rules/vm_attribute_manager'
require 'cloud/vsphere/drs_rules/drs_lock'

module VSphereCloud
  class DrsRuleCleaner
    CUSTOM_ATTRIBUTE_NAME = 'drs_rule'

    def initialize(cloud_searcher, custom_fields_manager, logger)
      @cloud_searcher = cloud_searcher
      @custom_fields_manager = custom_fields_manager
      @logger = logger

      @vm_attribute_manager = VMAttributeManager.new(
        @custom_fields_manager,
        @logger
      )
    end

    def clean
      DrsLock.new(@vm_attribute_manager, @logger).with_drs_lock do
        unless has_tagged_vms?
          @logger.info('Cleaning drs rule attribute')
          @vm_attribute_manager.delete(CUSTOM_ATTRIBUTE_NAME)
        end
      end
    end

    private

    def has_tagged_vms?
      custom_attribute = @vm_attribute_manager.find_by_name(CUSTOM_ATTRIBUTE_NAME)
      return [] unless custom_attribute

      @cloud_searcher.has_managed_object_with_attribute?(
        VimSdk::Vim::VirtualMachine,
        custom_attribute.key
      )
    end
  end
end
