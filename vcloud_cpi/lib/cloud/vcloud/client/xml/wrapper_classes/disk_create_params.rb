module VCloudCloud
  module Client
    module Xml
        class DiskCreateParams < Wrapper
          def bus_type=(value)
            disk['busType'] = value.to_s
          end

          def bus_sub_type=(value)
            disk['busSubType'] = value.to_s
          end

          def name=(name)
            disk['name'] = name.to_s
          end

          def size_bytes=(value)
            disk['size'] = value.to_s
          end

          def add_locality(local)
            raise "Cannot add locality more than once to DiskCreateParams" if !@local_exists.nil? && @local_exists
            @local_exists = true
            node = create_child('Locality')
            node['href'] = local.href
            # Bug in create independent disk API.  It needs the UUID part of the ID instead of
            # the entire ID like other REST API calls.
            node['id'] = extract_uuid(local.urn)
            node['type'] = MEDIA_TYPE[:VM]
            disk.node.after(node)
          end

          private

          def disk
            get_nodes('Disk').pop
          end

          def extract_uuid(id)
            id.split(':').pop
          end

        end
    end
  end
end
