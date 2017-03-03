module Bosh
  module Director
    module Digest
      class MultiDigest
        SHA1 = 'sha1'
        SHA256 = 'sha256'

        def initialize(logger, multi_digest_binary_path=Config.verify_multidigest_path)
          @multidigest_path = multi_digest_binary_path
          @logger = logger
        end

        def verify(file_path, expected_multi_digest_sha)
          cmd = "#{@multidigest_path} verify-multi-digest #{file_path} '#{expected_multi_digest_sha}'"
          @logger.info("Verifying file shasum with command: \"#{cmd}\"")
          _, err, status = Open3.capture3(@multidigest_path, "verify-multi-digest", file_path, expected_multi_digest_sha)
          unless status.exitstatus == 0
            raise ShaMismatchError, "#{err}"
          end
          @logger.info("Shasum matched for file: '#{file_path}' digest: '#{expected_multi_digest_sha}'")
        end

        def create(algorithms, file_path)
          cmd = "#{@multidigest_path} create-multi-digest #{algorithms.join(",")} #{file_path}"
          @logger.info("Creating digest with command: \"#{cmd}\"")
          out, err, status = Open3.capture3(@multidigest_path, 'create-multi-digest', algorithms.join(","), file_path)
          unless status.exitstatus == 0
            raise DigestCreationError, "#{err}"
          end
          @logger.info("Digest '#{out}' created for file: '#{file_path}'")
          out
        end
      end
    end
  end
end
