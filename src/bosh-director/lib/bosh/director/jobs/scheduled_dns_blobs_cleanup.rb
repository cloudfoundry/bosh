module Bosh::Director
  module Jobs
    class ScheduledDnsBlobsCleanup < BaseJob
      @queue = :normal

      def self.job_type
        :scheduled_dns_blobs_cleanup
      end

      def self.has_work(params)
        max_blob_age = params.first['max_blob_age']
        num_dns_blobs_to_keep = params.first['num_dns_blobs_to_keep']

        if Models::LocalDnsBlob.count > num_dns_blobs_to_keep
          return Models::LocalDnsBlob.where(Sequel.lit('created_at < ?', Time.now - max_blob_age)).any?
        end

        return false
      end

      def self.schedule_message
        'clean up local dns blobs'
      end

      def initialize(params = {})
        @max_blob_age = params['max_blob_age']
        @num_blobs_to_keep = params['num_dns_blobs_to_keep']
      end

      def perform
        cutoff_time = Time.now - @max_blob_age
        new_blob_count = Models::LocalDnsBlob.where(Sequel.lit('created_at >= ?', cutoff_time)).count
        old_blobs = Models::LocalDnsBlob.where(Sequel.lit('created_at < ?', cutoff_time)).all

        num_deleted = 0

        while old_blobs.length + new_blob_count > @num_blobs_to_keep
          break if old_blobs.length == 0

          blob_to_delete = old_blobs.shift
          App.instance.blobstores.blobstore.delete(blob_to_delete.blob.blobstore_id)
          blob_to_delete.delete
          blob_to_delete.blob.delete
          num_deleted += 1
        end

        "Deleted #{num_deleted} dns blob(s) created before #{cutoff_time}"
      end
    end
  end
end
