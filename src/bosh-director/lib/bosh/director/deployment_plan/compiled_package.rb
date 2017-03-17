module Bosh::Director
  module DeploymentPlan
    class CompiledPackage

      # @return [Models::CompiledPackage] Compiled package DB model
      attr_reader :model

      # @return [String] Package name
      attr_reader :name

      # @return [String] Package version
      attr_reader :version

      # @param [Models::CompiledPackage]
      def initialize(model)
        @model = model

        @name = model.package.name
        @version = model.package.version
      end

      # @return [Hash<String,Object>] Hash representation
      def spec
        {
          "name" => @name,
          "version" => "#{@version}.#{@model.build}",
          "sha1" => @model.sha1,
          "blobstore_id" => @model.blobstore_id
        }
      end
    end
  end
end