module VCloudSdk

  class CloudError < RuntimeError; end

  class VappSuspendedError < CloudError; end
  class VmSuspendedError < CloudError; end
  class VappPoweredOffError < CloudError; end

  class ObjectNotFoundError < CloudError; end

  class DiskNotFoundError < ObjectNotFoundError; end
  class CatalogMediaNotFoundError < ObjectNotFoundError; end

  class ApiError < CloudError; end

  class ApiRequestError < ApiError; end
  class ApiTimeoutError < ApiError; end

  class CpiError < CloudError; end

end
