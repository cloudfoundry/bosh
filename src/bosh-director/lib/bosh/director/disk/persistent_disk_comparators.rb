module Bosh::Director::Disk
  class PersistentDiskComparator
    def initialize
      @variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
    end

    def is_equal?(first_pair, second_pair)
      return false unless is_persistent_disk?(first_pair.disk) && is_persistent_disk?(second_pair.disk)

      is_cloud_properties_equal?(first_pair, second_pair) &&
        is_name_equal?(first_pair, second_pair) &&
        is_size_equal?(first_pair, second_pair)
    end

    def size_diff_only?(first_pair, second_pair)
      return false unless is_persistent_disk?(first_pair.disk) && is_persistent_disk?(second_pair.disk)

      is_cloud_properties_equal?(first_pair, second_pair) &&
        is_name_equal?(first_pair, second_pair) &&
        !is_size_equal?(first_pair, second_pair)
    end

    private

    def is_persistent_disk?(disk)
      disk.is_a? Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk
    end

    def is_name_equal?(first_pair, second_pair)
      first_pair.disk.name == second_pair.disk.name
    end

    def is_size_equal?(first_pair, second_pair)
      first_pair.disk.size == second_pair.disk.size
    end

    def is_cloud_properties_equal?(first_pair, second_pair)
      different = @variables_interpolator.interpolated_versioned_variables_changed?(first_pair.disk.cloud_properties,
                                                                                  second_pair.disk.cloud_properties,
                                                                                  first_pair.variable_set,
                                                                                  second_pair.variable_set)
      !different
    end
  end

  class PersistentDiskVariableSetPair
    attr_reader :disk, :variable_set

    def initialize(disk, variable_set)
      @disk = disk
      @variable_set = variable_set
    end
  end
end
