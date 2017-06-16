module Bosh::Director
  module DeploymentPlan
    class PersistentDiskCollection
      include Enumerable

      attr_reader :collection

      def initialize(logger)
        @collection = []
        @logger = logger
      end

      def each(&block)
        @collection.each(&block)
      end

      def add_by_disk_size(disk_size)
        raise Exception, 'This instance group is not supposed to have multiple disks,
                          but tried to attach multiple disks.' if @collection.size > 0

        add_to_collection(ManagedPersistentDisk.new(DiskType.new(SecureRandom.uuid, disk_size, {})))
      end

      def add_by_disk_type(disk_type)
        raise Exception, 'This instance group is not supposed to have multiple disks,
                        but tried to attach multiple disks.' if @collection.size > 0

        add_to_collection(ManagedPersistentDisk.new(disk_type))
      end

      def add_by_model(disk_model)
        add_to_collection(ModelPersistentDisk.new(disk_model))
      end

      def add_by_disk_name_and_type(disk_name, disk_type)
        unless collection.find { |disk| disk.managed? }.nil?
          raise Exception, 'This instance group cannot have multiple disks when using a managed disk.'
        end

        add_to_collection(NewPersistentDisk.new(disk_name, disk_type))
      end

      def non_managed_disks
        collection.reject { |disk| disk.managed? }
      end

      def needs_disk?
        collection.length > 0
      end

      def changed_disk_pairs(old_persistent_disk_collection)
        paired = []

        each do |new_disk|
          old_disk = old_persistent_disk_collection.find { |disk| new_disk.name == disk.name }

          paired << {
            old: old_disk,
            new: new_disk,
          }
        end

        old_persistent_disk_collection.each do |old_disk|
          new_disk = find { |disk| old_disk.name == disk.name }

          if new_disk.nil?
            paired << {
              old: old_disk,
              new: new_disk,
            }
          end
        end

        paired.select { |disk_pair| disk_pair[:old] != disk_pair[:new] }
      end

      def generate_spec
        if @collection.empty?
          return {'persistent_disk' => 0}
        end

        spec = {}

        if collection.length == 1 && collection[0].managed?
          # supply both for reverse compatibility with old agent
          spec['persistent_disk'] = collection[0].size
          # old agents will ignore this pool
          # keep disk pool for backwards compatibility
          spec['persistent_disk_pool'] = collection[0].spec
          spec['persistent_disk_type'] = collection[0].spec
        end

        spec
      end

      private

      def add_to_collection(disk)
        @collection << disk
      end

      class PersistentDisk
        attr_reader :name, :cloud_properties, :size

        def initialize(name, cloud_properties, size)
          @name = name
          @cloud_properties = cloud_properties
          @size = size
        end

        def to_s
          {name: name, size: size, cloud_properties: cloud_properties}.inspect
        end

        def managed?
          name == ''
        end

        def ==(other)
          return false unless other.is_a? PersistentDisk
          cloud_properties == other.cloud_properties &&
            size == other.size && name == other.name
        end

        def size_diff_only?(other)
          return false unless other.is_a? PersistentDisk
          cloud_properties == other.cloud_properties &&
            size != other.size && name == other.name
        end
      end

      class NewPersistentDisk < PersistentDisk
        attr_reader :spec

        def initialize(name, type)
          super(name, type.cloud_properties, type.disk_size)
          @spec = type.spec
        end
      end

      class ManagedPersistentDisk < PersistentDisk
        attr_reader :spec

        def initialize(type)
          super('', type.cloud_properties, type.disk_size)
          @spec = type.spec
        end
      end

      class ModelPersistentDisk < PersistentDisk
        attr_reader :model

        def initialize(disk_model)
          @model = disk_model
          super(disk_model.name, disk_model.cloud_properties, disk_model.size)
        end
      end
    end
  end
end
