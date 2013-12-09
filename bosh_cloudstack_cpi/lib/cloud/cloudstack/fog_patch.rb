module Fog
  module Compute
    class Cloudstack
      request :create_tags
      request :delete_tags
      request :list_tags
      request :create_template
      request :associate_ip_address
      request :disassociate_ip_address
      request :create_vlan_ip_range
      request :delete_vlan_ip_range
      request :list_vlan_ip_ranges
      request :enable_static_nat
      request :disable_static_nat
      request :copy_template

      model :nat
      collection :nats
      model :vlan
      collection :vlans
      model :ipaddress
      collection :ipaddresses
      model :network
      collection :networks
      model :disk_offering
      collection :disk_offerings
      model :key_pair
      collection :key_pairs
      model :ostype
      collection :ostypes
      model :firewall
      collection :firewalls

      require ('fog/cloudstack/models/compute/volume')
      class Volume < Fog::Model
        attribute :device_id, :aliases => 'deviceid'
      end

      require ('fog/cloudstack/models/compute/disk_offering')
      class DiskOffering < Fog::Model
        # fix attribute name typo
        attribute :display_text,    :aliases => 'displaytext'
        attribute :disk_size,    :aliases => 'disksize'
      end

      require ('fog/cloudstack/models/compute/snapshot')
      class Snapshot < Fog::Model
        # return job
        def destroy
          requires :id
          data = service.delete_snapshot('id' => id)
          service.jobs.new(data["deletesnapshotresponse"])
        end
      end

      require ('fog/cloudstack/models/compute/snapshots')
      class Snapshots < Fog::Collection
        # eliminate exceptions
        def get(snapshot_id)
          snapshots = service.list_snapshots('id' => snapshot_id)["listsnapshotsresponse"]["snapshot"]
          unless snapshots.nil? || snapshots.empty?
              new(snapshots.first)
          end
        rescue Fog::Compute::Cloudstack::BadRequest
          nil
        end
      end


      require ('fog/cloudstack/models/compute/image')
      class Image < Fog::Model
        def copy(to_zone)
          requires :id
          requires :zone_id
          data = service.copy_template('id' => id, 'sourcezoneid' => zone_id, 'destzoneid' => to_zone.id)
          service.jobs.new(data["copytemplateresponse"])
        end
      end

    end
  end
end
