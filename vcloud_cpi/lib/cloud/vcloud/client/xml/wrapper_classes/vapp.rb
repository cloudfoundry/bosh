module VCloudCloud
  module Client
    module Xml
      class VApp < Wrapper

        def description
          get_nodes('Description').pop.content
        end

        def network_config_section
          get_nodes('NetworkConfigSection').pop
        end

        def power_on_link
          get_nodes('Link', {'rel' => 'power:powerOn'}, true).pop
        end

        def power_off_link
          get_nodes('Link', {'rel' => 'power:powerOff'}, true).pop
        end

        def reboot_link
          get_nodes('Link', {'rel' => 'power:reboot'}, true).pop
        end

        def remove_link
          get_nodes('Link', {'rel' => 'remove'}, true).pop
        end

        def running_tasks
          get_nodes('Task', {'status' => 'running'})
        end

        def tasks
          get_nodes('Task')
        end

        def undeploy_link
          get_nodes('Link', {'rel' => 'undeploy'}, true).pop
        end

        def discard_state
          get_nodes('Link', {'rel' => 'discardState'}, true).pop
        end

        def vms
          get_nodes('Vm')
        end

        def vm(name)
          get_nodes('Vm', {'name' => name}).pop
        end

      end
    end
  end
end
