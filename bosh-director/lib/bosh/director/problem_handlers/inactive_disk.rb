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
          handler_error("Disk `#{@disk_id}' is no longer in the database")
        end

        if @disk.active
          handler_error("Disk `#{@disk.disk_cid}' is no longer inactive")
        end

        @instance = @disk.instance
        if @instance.nil?
          handler_error("Cannot find instance for disk `#{@disk.disk_cid}'")
        end

        @vm = @instance.vm
      end

      def description
        job = @instance.job || "unknown job"
        index = @instance.index || "unknown index"
        disk_label = "`#{@disk.disk_cid}' (#{job}/#{index}, #{@disk.size.to_i}M)"
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

        if @vm
          begin
            cloud.detach_disk(@vm.cid, @disk.disk_cid)
          rescue => e
            # We are going to delete this disk anyway
            # and we know it's not in use, so we can ignore
            # detach errors here.
            @logger.warn(e)
          end
        end

        # FIXME: Currently there is no good way to know if delete_disk
        # failed because of cloud error or because disk doesn't exist
        # in vsphere_disks.
        begin
          cloud.delete_disk(@disk.disk_cid)
        rescue Bosh::Clouds::DiskNotFound, RuntimeError => e # FIXME
          @logger.warn(e)
        end

        @disk.destroy
      end

      def disk_mounted?
        return false if @vm.nil?

        begin
          agent_timeout_guard(@vm) do |agent|
            agent.list_disk.include?(@disk.disk_cid)
          end
        rescue RuntimeError
          # old stemcells without 'list_disk' support. We need to play
          # conservative and assume that the disk is mounted.
          true
        end
      end
    end
  end
end
