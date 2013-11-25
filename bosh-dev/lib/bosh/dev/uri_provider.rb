module Bosh::Dev
  class UriProvider
    PIPELINE_BUCKET = 'http://bosh-ci-pipeline.s3.amazonaws.com'
    ARTIFACTS_BUCKET = 'http://bosh-jenkins-artifacts.s3.amazonaws.com'

    def self.pipeline_uri(remote_directory_path, file_name)
      uri(PIPELINE_BUCKET, remote_directory_path, file_name)
    end

    def self.artifacts_uri(remote_directory_path, file_name)
      uri(ARTIFACTS_BUCKET, remote_directory_path, file_name)
    end

    private

    def self.uri(base_uri, remote_directory_path, file_name)
      remote_file_path = File.join(remote_directory_path, file_name)
      URI.parse("#{base_uri}/#{remote_file_path}")
    end
  end
end
