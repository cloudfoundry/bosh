# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class BlobManagement < Base

    # Prints out blobs status
    def status
      blob_manager.print_status
    end

    # Adds blob to managed blobs
    # @param [String] local_path Local file path
    # @param [optional, String] blob_dir Directory to store blob in, relative
    #     to blobs dir
    def add(local_path, blob_dir = nil)
      blob_path = File.basename(local_path)
      if blob_dir
        # We don't need about blobs prefix,
        # but it might be handy for people who rely on auto-completion
        if blob_dir[0..5] == "blobs/"
          blob_dir = blob_dir[6..-1]
        end
        blob_path = File.join(blob_dir, blob_path)
      end
      blob_manager.add_blob(local_path, blob_path)
    end

    # Uploads all blobs that need to be uploaded
    def upload
      blob_manager.print_status

      blob_manager.blobs_to_upload.each do |blob|
        nl
        if confirmed?("Upload blob #{blob.yellow}?")
          blob_manager.upload_blob(blob)
        end
      end
    end

    # Syncs blobs with blobstore
    def sync
      blob_manager.sync
      blob_manager.print_status
    end

  end
end
