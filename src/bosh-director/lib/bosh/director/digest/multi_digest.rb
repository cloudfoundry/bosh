module Bosh
  module Director
    module Digest
      class MultiDigest

        def initialize(logger)
          @multidigest_path = Config.verify_multidigest_path
          @logger = logger
        end

        def verify(file_path, expected_multi_digest_sha)
          cmd = "#{@multidigest_path} verify-multi-digest #{file_path} '#{expected_multi_digest_sha}'"
          @logger.info("Verifying file shasum with command: \"#{cmd}\"")
          _, err, status = Open3.capture3(cmd)
          unless status.exitstatus == 0
            raise ShaMismatchError, "sha1 mismatch expected='#{expected_multi_digest_sha}', error: '#{err}'"
          end
          @logger.info("Shasum matched for file: '#{file_path}' digest: '#{expected_multi_digest_sha}'")
        end
      end
    end
  end
end
