# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module ProblemHandlers
    class InactiveDisk < Base

      register_as :inactive_disk
      auto_resolution :ignore

      def initialize(disk_id, data)
        super
        @disk_id = disk_id
        @data = data
        @disk = Models::PersistentDisk[@disk_id]

        if @disk.nil?
          handler_error("Disk '#{@disk_id}' is no longer in the database")
        end

        if @disk.active
          handler_error("Disk '#{@disk.disk_cid}' is no longer inactive")
        end

        @instance = @disk.instance
        if @instance.nil?
          handler_error("Cannot find instance for disk '#{@disk.disk_cid}'")
        end
      end

      def description
        job = @instance.job || "unknown job"
        uuid = @instance.uuid || "unknown id"
        index = @instance.index || "unknown index"
        disk_label = "'#{@disk.disk_cid}' (#{@disk.size.to_i}M) for instance '#{job}/#{uuid} (#{index})'"
        "Disk #{disk_label} is inactive"
      end

      resolution :ignore do
        plan { "Skip for now" }
        action { }
      end

      resolution :delete_disk do
        plan { "Delete disk" }
        action { delete_disk }
      end

      resolution :activate_disk do
        plan { "Activate disk" }
        action { activate_disk }
      end

      def activate_disk
        unless disk_mounted?
          handler_error("Disk is not mounted")
        end
        # Currently the director allows ONLY one persistent disk per
        # instance. We are about to activate a disk but the instance already
        # has an active disk.
        # For now let's be conservative and return an error.
        if @instance.persistent_disk
          handler_error("Instance already has an active disk")
        end
        @disk.active = true
        @disk.save
      end

      def delete_disk
        if disk_mounted?
          handler_error("Disk is currently in use")
        end

        if @instance.vm_cid
          begin
            cloud.detach_disk(@instance.vm_cid, @disk.disk_cid)
          rescue => e
            # We are going to delete this disk anyway
            # and we know it's not in use, so we can ignore
            # detach errors here.
            @logger.warn(e)
          end
        end

        DiskManager.new(cloud, @logger).orphan_disk(@disk)
      end

      def disk_mounted?
        return false unless @instance.vm_cid
        agent_timeout_guard(@instance.vm_cid, @instance.credentials, @instance.agent_id) do |agent|
          agent.list_disk.include?(@disk.disk_cid)
        end
      end
    end
  end
end
