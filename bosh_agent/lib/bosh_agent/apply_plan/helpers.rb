module Bosh::Agent
  module ApplyPlan
    module Helpers

      private

      def validate_spec(spec)
        unless spec.is_a?(Hash)
          raise ArgumentError, "Invalid #{self.class} spec: Hash expected, #{spec.class} given"
        end

        required_keys = %w(name version sha1 blobstore_id)
        missing_keys = required_keys.select { |k| spec[k].nil? }
        unless missing_keys.empty?
          raise ArgumentError, "Invalid #{self.class} spec: #{missing_keys.join(', ')} missing"
        end
      end

      def fetch_bits
        FileUtils.mkdir_p(File.dirname(@install_path))
        FileUtils.mkdir_p(File.dirname(@link_path))

        # Once directory is created we'll never do the fetch a second time;
        # we make a best effort to ensure directory is in a consistent state
        unless Dir.exist?(@install_path)
          Bosh::Agent::Util.unpack_blob(@blobstore_id, @checksum, @install_path)
        end
      end

      def fetch_bits_and_symlink
        fetch_bits
        Bosh::Agent::Util.create_symlink(@install_path, @link_path)
      end
    end
  end
end
