module Bosh::Director

  class DiskCheck < BaseCloudCheck

    # scan for all errors related to persistent disks.
    def scan
      reset # all scans start from scratch
      Models::PersistentDisk.filter(:active => false).all.each do |disk_error|
        Models::CloudError.create(:type => :disk, :data => json_encode({:disk_cid => disk_error.disk_cid}))
      end
    end

    # delete all disk-error records
    def reset
      Models::CloudError.filter(:type => 'disk').all.each do |disk_error|
        disk_error.destroy
      end
    end

    # given a error-record return all possible solutions.
    # BOSH admin will pick one of the options and apply the fix.
    #
    # XXX CLI should consume the description and return with the solution name.
    # We should be able to run some code to determine the possible solution.
    # Different error can have different available solution... except for info
    # and check.. which should be common to all.
    def list_solutions(err)
      [ ["Return detailed info about the incident", 'fix_info'],
        ["Double check", 'fix_check'],
        ["Delete the persistent disk record", 'fix_delete_persistent_disk']
      ]
    end

    # default operation.
    def fix_default(err)
      # don't try to be smart with persistent-disks. Just return information
      # about the incosistency so that the BOSH admin can address the issue.
      fix_info(err)
    end

    def fix_info(err)
      disk_cid = get_disk_cid(err)
    end

    # way to double check if the reported incident is still an error.
    def fix_check(err)
      disk_cid = get_disk_cid(err)
      persistent_disk = Models::PersistentDisk.filter(:disk_cid => disk_cid)

      # problem is now solved
      if persistent_disk.nil? || persistent_disk.active
        err.destroy
      end
    end

    def fix_delete_persistent_disk(err)
      disk_cid = get_disk_cid(err)

      # 1- Check that no agent/instance has this disk_cid in use.
    end

    def get_disk_cid(err)
      error_info = json_decode(err.data)
      disk_cid = error_info['disk_cid'].to_i
    end
  end
end
