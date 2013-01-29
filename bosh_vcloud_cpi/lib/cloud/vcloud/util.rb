module VCloudCloud

  class Util
    class << self

      def retry_operation(op, attempts, backoff, &b)
        attempts.times do |attempt|
          begin
            return b.call
          rescue VCloudSdk::ApiError => e
            raise e if attempt >= attempts-1
            delay = backoff ** attempt
            Bosh::Clouds.Config.logger.error("Retry-attempt #{attempt+1}/" +
              "#{attempts} failed to #{op}, retrying in #{delay} seconds.\t#{e}")
            sleep (delay)
          end
        end
      end

    end
  end

end
