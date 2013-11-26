module Bosh::Dev
  class UriProvider
    PIPELINE_BUCKET  = 'bosh-ci-pipeline'
    ARTIFACTS_BUCKET = 'bosh-jenkins-artifacts'

    def self.pipeline_uri(remote_directory_path, file_name)
      uri(PIPELINE_BUCKET, remote_directory_path, file_name)
    end

    def self.pipeline_s3_path(remote_directory_path, file_name)
      s3_path(PIPELINE_BUCKET, remote_directory_path, file_name)
    end

    def self.artifacts_uri(remote_directory_path, file_name)
      uri(ARTIFACTS_BUCKET, remote_directory_path, file_name)
    end

    def self.artifacts_s3_path(remote_directory_path, file_name)
      s3_path(ARTIFACTS_BUCKET, remote_directory_path, file_name)
    end

    private

    def self.uri(bucket, remote_directory_path, file_name)
      remote_file_path = File.join(remote_directory_path, file_name)
      URI.parse("http://#{bucket}.s3.amazonaws.com/#{remote_file_path}")
    end

    def self.s3_path(bucket, remote_directory_path, file_name)
      remote_file_path = File.join('/', remote_directory_path, file_name)
      "s3://#{bucket}#{remote_file_path}"
    end
  end
end
