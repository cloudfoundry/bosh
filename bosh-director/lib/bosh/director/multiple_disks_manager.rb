module Bosh::Director
  class MultipleDisksManager

    def initialize(cloud, logger)
      @cloud = cloud
      @logger = logger
    end

    def update_persistent_disk(instance_plan)
    end

    def attach_disks_if_needed(instance_plan)
    end

    def delete_persistent_disks(instance_model)
    end

    def unmount_disk_for(instance_plan)
    end

    def attach_disk(instance_model)
    end

    def detach_disk(instance_model, disk)
    end

    def unmount_disk(instance_model, disk)
    end
  end
end
