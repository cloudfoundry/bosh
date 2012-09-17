module VCloudCloud
  class Util
    class << self

      def retry_operation(op, attempts, backoff, &b)
        attempts.times do |attempt|
          begin
            return b.call
          rescue ApiError => ex
            raise ex if attempt >= attempts-1
            delay = backoff ** attempt
            Config.logger.error("Retry-attempt #{attempt+1}/#{attempts} " +
                "failed to #{op}, retrying in #{delay} seconds.\t#{ex}")
            sleep (delay)
          end
        end
      end

    end
  end
end
