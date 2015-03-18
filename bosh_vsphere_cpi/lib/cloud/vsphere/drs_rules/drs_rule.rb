module VSphereCloud
  class DrsRule
    CUSTOM_ATTRIBUTE_NAME = 'drs_rule'

    def initialize(rule_name, client, cloud_searcher, datacenter_cluster, logger)
      @rule_name = rule_name
      @client = client
      @cloud_searcher = cloud_searcher
      @datacenter_cluster = datacenter_cluster
      @logger = logger

      @vm_attribute_manager = VMAttributeManager.new(
        client.service_content.custom_fields_manager,
        @logger
      )
    end

    def add_vm(vm)
      tag_vm(vm)

      DrsLock.new(@vm_attribute_manager, @logger).with_drs_lock do
        rule = find_rule
        if rule
          update_rule(rule.key)
        else
          add_rule
        end
      end
    end

    private

    def tag_vm(vm)
      custom_attribute = @vm_attribute_manager.find_by_name(CUSTOM_ATTRIBUTE_NAME)
      unless custom_attribute
        @logger.debug('Creating DRS rule attribute')
        @vm_attribute_manager.create(CUSTOM_ATTRIBUTE_NAME)
      end

      @logger.debug("Updating DRS rule attribute value: #{@rule_name}, vm: #{vm.name}")
      vm.set_custom_value(CUSTOM_ATTRIBUTE_NAME, @rule_name)
    end

    def find_rule
      @datacenter_cluster.configuration_ex.rule.find { |r| r.name == @rule_name }
    end

    def add_rule
      @logger.debug("Adding DRS rule: #{@rule_name}")
      reconfigure_cluster('add')
    end

    def update_rule(rule_key)
      @logger.debug("Updating DRS rule: #{@rule_name}")
      reconfigure_cluster('edit', rule_key)
    end

    def reconfigure_cluster(operation, rule_key = nil)
      config_spec = VimSdk::Vim::Cluster::ConfigSpecEx.new
      rule_spec = VimSdk::Vim::Cluster::RuleSpec.new
      rule_spec.operation = operation

      rule_info = VimSdk::Vim::Cluster::AntiAffinityRuleSpec.new
      rule_info.enabled = true
      rule_info.name = @rule_name
      rule_info.vm = tagged_vms
      @logger.debug("Setting DRS rule: #{@rule_name}, vms: #{rule_info.vm}")
      rule_info.key = rule_key if rule_key

      rule_spec.info = rule_info

      config_spec.rules_spec = [rule_spec]
      task = @datacenter_cluster.reconfigure_ex(config_spec, true)
      @client.wait_for_task(task)
    end

    def tagged_vms
      custom_attribute = @vm_attribute_manager.find_by_name(CUSTOM_ATTRIBUTE_NAME)
      return [] unless custom_attribute

      @cloud_searcher.get_managed_objects_with_attribute(
        VimSdk::Vim::VirtualMachine,
        custom_attribute.key,
        value: @rule_name
      )
    end
  end
end
