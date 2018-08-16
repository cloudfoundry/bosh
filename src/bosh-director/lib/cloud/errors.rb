module Bosh
  module Clouds
    class CpiError < StandardError; end
    class NotImplemented < CpiError; end
    class NotSupported < CpiError; end
    class AttachDiskResponseError < CpiError; end

    class CloudError < StandardError; end
    class VMNotFound < CloudError; end
    class NetworkNotFound < CloudError; end

    class RetriableCloudError < CloudError
      attr_accessor :ok_to_retry

      def initialize(ok_to_retry)
        @ok_to_retry = ok_to_retry
      end
    end

    class NoDiskSpace < RetriableCloudError; end
    class DiskNotAttached < RetriableCloudError; end
    class DiskNotFound < RetriableCloudError; end
    class VMCreationFailed < RetriableCloudError; end
  end
end
