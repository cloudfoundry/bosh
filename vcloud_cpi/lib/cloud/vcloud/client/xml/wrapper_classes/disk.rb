module VCloudCloud
  module Client
    module Xml
        class Disk < Wrapper
          def bus_type=(value)
            @root['busType'] = value.to_s
          end

          def bus_sub_type=(value)
            @root['busSubType'] = value.to_s
          end

          def delete_link
            get_nodes('Link', {'rel' => 'remove'}, true).pop
          end

          def name=(name)
            @root['name'] = name.to_s
          end

          def running_tasks
            tasks.find_all {|t| t.status == TASK_STATUS[:RUNNING] ||
                t.status == TASK_STATUS[:QUEUED] ||
                t.status == TASK_STATUS[:PRE_RUNNING]}
          end

          def tasks
            get_nodes('Task')
          end

        end
    end
  end
end