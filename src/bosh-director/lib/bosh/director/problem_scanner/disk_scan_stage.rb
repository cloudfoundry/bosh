module Bosh::Director::ProblemScanner
  class DiskScanStage
    def initialize(disk_owners, problem_register, deployment_id, event_logger, logger)
      @disk_owners = disk_owners
      @problem_register = problem_register
      @deployment_id = deployment_id
      @event_logger = event_logger
      @logger = logger
    end

    def scan
      disks = Bosh::Director::Models::PersistentDisk.eager(:instance).all.select do |disk|
        disk.instance && disk.instance.deployment_id == @deployment_id && !disk.instance.ignore
      end

      results = Hash.new(0)

      @event_logger.begin_stage("Scanning #{disks.size} persistent disks", 2)

      lock = Mutex.new
      @event_logger.track_and_log('Looking for inactive disks') do
        Bosh::Director::ThreadPool.new(max_threads: Bosh::Director::Config.max_threads).wrap do |pool|
          disks.each do |disk|
            pool.process do
              scan_result = scan_disk(disk)
              lock.synchronize { results[scan_result] += 1 }
            end
          end
        end
      end

      @event_logger.track_and_log("#{results[:ok]} OK, " +
        "#{results[:missing]} missing, " +
        "#{results[:inactive]} inactive, " +
        "#{results[:mount_info_mismatch]} mount-info mismatch")
    end

    private

    def scan_disk(disk)
      begin
        factory = Bosh::Director::AZCloudFactory.create_with_latest_configs(disk.instance.deployment)
        cloud = factory.get_for_az(disk.instance.availability_zone)
        unless cloud.has_disk(disk.disk_cid)
          @logger.info("Found missing disk: #{disk.id}")
          @problem_register.problem_found(:missing_disk, disk)
          return :missing
        end
      rescue Bosh::Clouds::NotImplemented
        @logger.info('Ignored check for disk presence, CPI does not implement has_disk method')
      end

      # inactive disks
      unless disk.active
        @logger.info("Found inactive disk: #{disk.id}")
        @problem_register.problem_found(:inactive_disk, disk)
        return :inactive
      end

      disk_cid = disk.disk_cid
      vm_cid = disk.instance.vm_cid if disk.instance

      if vm_cid.nil?
        # With the db dependencies this should not happen.
        @logger.warn("Disk #{disk_cid} is not associated to any VM. " +
          "Skipping scan")
        return :ok
      end

      owner_vms = @disk_owners[disk_cid] || []
      # active disk is not mounted or mounted more than once -or-
      # the disk is mounted on a vm that is different form the record.
      if owner_vms.size != 1 || owner_vms.first != vm_cid
        @logger.info("Found problem in mount info: " +
          "active disk #{disk_cid} mounted on " +
          "#{owner_vms.join(', ')}")
        @problem_register.problem_found(:mount_info_mismatch, disk, owner_vms: owner_vms)
        return :mount_info_mismatch
      end
      :ok
    end
  end
end
