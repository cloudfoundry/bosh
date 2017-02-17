module Bosh::Director::Core::Templates
  class CachingJobTemplateFetcher
    def initialize
      @downloaded_paths = {}
      @semaphore = Mutex.new
    end

    def download_blob(job_template)
      blobstore_id = job_template.blobstore_id
      @semaphore.synchronize { @downloaded_paths[blobstore_id] ||= job_template.download_blob }
    end

    def clean_cache!
      @downloaded_paths.values.each do |blob_path|
        FileUtils.rm_f(blob_path)
      end
      @downloaded_paths = {}
    end
  end
end
