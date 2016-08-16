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
        add_to_collection(LegacyPersistentDisk.new(DiskType.new(SecureRandom.uuid, disk_size, {})))

        raise Exception, 'This instance group is not supposed to have multiple disks,
                          but tried to attach multiple disks.' if @collection.size > 1
      end

      def add_by_disk_type(disk_type)
        add_to_collection(LegacyPersistentDisk.new(disk_type))

        raise Exception, 'This instance group is not supposed to have multiple disks,
                        but tried to attach multiple disks.' if @collection.size > 1
      end

      def add_by_model(disk_model)
        add_to_collection(ModelPersistentDisk.new(disk_model))
      end

      def add_by_disk_name_and_type(disk_name, disk_type)
        #TODO: make sure collection is a collection of new disks
        add_to_collection(NewPersistentDisk.new(disk_name, disk_type))
      end

      def needs_disk?
        collection.length > 0
      end

      def is_different_from(old_persistent_disk_collection)
        changed = false

        collection.each do |disk|
          old_disk = old_persistent_disk_collection.collection.find { |old_disk| disk.name == old_disk.name }

          if old_disk.nil?
            @logger.debug("Persistent disk added: size #{disk.size}, cloud_properties: #{disk.cloud_properties}")
            changed = true
          else
            change_detail = []
            change_detail << "size FROM #{old_disk.size} TO #{disk.size}" if disk.size != old_disk.size
            change_detail << "cloud_properties FROM #{old_disk.cloud_properties} TO #{disk.cloud_properties}" if disk.cloud_properties != old_disk.cloud_properties

            if change_detail.length > 0
              changed = true
              @logger.debug("Persistent disk changed: #{change_detail.join(', ')}")
            end
          end
        end

        old_persistent_disk_collection.collection.each do |disk|
          new_disk = @collection.find { |new_disk| disk.name == new_disk.name }

          if new_disk.nil?
            @logger.debug("Persistent disk removed: size #{disk.size}, cloud_properties: #{disk.cloud_properties}")
            changed = true
          end
        end

        changed
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

      def add_to_collection(disk)
        @collection << disk if disk.size > 0
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
