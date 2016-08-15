module Bosh::Director
  module DeploymentPlan
    class PersistentDiskCollection
      attr_reader :collection

      def initialize(logger, options={})
        #TODO: maybe change the way this boolean works
        @multiple_disks = options.fetch(:multiple_disks, false)
        @collection = []
        @logger = logger
      end

      def add_by_disk_size(disk_size)
        if disk_size > 0
          @collection << LegacyPersistentDisk.new(DiskType.new(SecureRandom.uuid, disk_size, {}))

          raise Exception, 'This instance group is not supposed to have multiple disks,
                            but tried to attach multiple disks.' if @collection.size > 1
        end
      end

      def add_by_disk_type(disk_type)
        @collection << LegacyPersistentDisk.new(disk_type)

        raise Exception, 'This instance group is not supposed to have multiple disks,
                        but tried to attach multiple disks.' if @collection.size > 1
      end

      def add_by_model(disk_model)
        @collection << ModelPersistentDisk.new(disk_model)
      end

      def add_by_disk_name_and_type(disk_name, disk_type)
        #TODO: make sure collection is a collection of new disks
        @collection << NewPersistentDisk.new(disk_name, disk_type)
      end

      def needs_disk?
        if @multiple_disks
          return @collection.size > 0
        else
          if @collection.size > 0
            return @collection.first.size > 0
          end
        end

        false
      end

      def is_different_from(persistent_disk_models)
        if @multiple_disks
          old_persistent_disk_collection = PersistentDiskCollection.new(@logger, {multiple_disks: @multiple_disks})
          persistent_disk_models.each do |model|
            old_persistent_disk_collection.add_by_model(model)
          end
          !collections_are_exact_set_matches(self, old_persistent_disk_collection)
        else
          diff_legacy_persistent_disk(persistent_disk_models)
        end
      end

      def create_disks(disk_creator, instance_id)
        if @multiple_disks
          []
        else
          disk_size = @collection.first.size
          cloud_properties = @collection.first.cloud_properties

          disk_cid = disk_creator.create(disk_size, cloud_properties)

          disk = Models::PersistentDisk.create(
            disk_cid: disk_cid,
            active: false,
            instance_id: instance_id,
            size: disk_size,
            cloud_properties: cloud_properties,
          )

          disk_creator.attach(disk_cid)

          [disk]
        end
      end

      def generate_spec
        if @collection.empty?
          return {'persistent_disk' => 0}
        end

        spec = {}

        @collection.each do |disk|
          if disk.is_a? LegacyPersistentDisk
            # supply both for reverse compatibility with old agent
            spec['persistent_disk'] = @collection.first.size
            # old agents will ignore this pool
            # keep disk pool for backwards compatibility
            spec['persistent_disk_pool'] = @collection.first.spec
            spec['persistent_disk_type'] = @collection.first.spec
          elsif disk.is_a? NewPersistentDisk
            spec['persistent_disks'] ||= []

            spec['persistent_disks'] << {
              'disk_size' => disk.size,
              'disk_name' => disk.name,
            }
          end
        end

        spec
      end

      private

      def diff_legacy_persistent_disk(persistent_disk_models)
        #TODO: what about moving from multiple disks to a single disk?

        old_disk_size = persistent_disk_models.empty? ? 0 : persistent_disk_models.first.size
        new_disk_size = @collection.empty? ? 0 : @collection.first.size
        changed = new_disk_size != old_disk_size
        if changed
          @logger.debug("Persistent disk size changed FROM: #{old_disk_size} TO: #{new_disk_size}")
          return true
        end

        old_disk_cloud_properties = persistent_disk_models.empty? ? 0 : persistent_disk_models.first.cloud_properties
        new_disk_cloud_properties = @collection.empty? ? {} : @collection.first.cloud_properties
        changed = new_disk_size != 0 && new_disk_cloud_properties != old_disk_cloud_properties
        if changed
          @logger.debug("Persistent disk cloud properties changed FROM: #{old_disk_cloud_properties} TO: #{new_disk_cloud_properties}")
          return true
        end

        changed
      end

      def collections_are_exact_set_matches(collection1, collection2)
        collection1 = collection1.collection.sort { |a, b| a.name <=> b.name }
        collection2 = collection2.collection.sort { |a, b| a.name <=> b.name }

        collection1 == collection2
      end

      class PersistentDisk
        attr_reader :name, :cloud_properties, :size

        def initialize(name, cloud_properties, size)
          @name = name
          @cloud_properties = cloud_properties
          @size = size
        end

        def ==(other)
          cloud_properties == other.cloud_properties &&
            size == other.size && name == other.name
        end
      end

      class NewPersistentDisk < PersistentDisk
        attr_reader :spec

        def initialize(name, type)
          super(name, type.cloud_properties, type.disk_size)
          @spec = type.spec
        end
      end

      class LegacyPersistentDisk < PersistentDisk
        attr_reader :spec

        def initialize(type)
          super('', type.cloud_properties, type.disk_size)
          @spec = type.spec
        end
      end

      class ModelPersistentDisk < PersistentDisk
        def initialize(disk_model)
          super(disk_model.name, disk_model.cloud_properties, disk_model.size)
        end
      end
    end
  end
end
