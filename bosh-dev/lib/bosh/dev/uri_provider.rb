module Bosh::Dev
  class UriProvider
    PIPELINE_BUCKET = 'http://bosh-ci-pipeline.s3.amazonaws.com'

    def self.pipeline_uri(remote_directory_path, file_name)
      remote_file_path = File.join(remote_directory_path, file_name)
      URI.parse("#{PIPELINE_BUCKET}/#{remote_file_path}")
    end
  end
end
