# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class PackageSpec
      attr_accessor :package
      attr_accessor :compiled_package

      def initialize(package, compiled_package)
        @package = package
        @compiled_package = compiled_package
      end

      def spec
        {
            "name" => @package.name,
            "version" => "#{@package.version}.#{@compiled_package.build}",
            "sha1" => @compiled_package.sha1,
            "blobstore_id" => @compiled_package.blobstore_id
        }
      end
    end
  end
end