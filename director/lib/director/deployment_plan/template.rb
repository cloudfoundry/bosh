# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class Template

      attr_reader :name
      attr_reader :release

      attr_reader :model
      attr_reader :package_models

      # @param [DeploymentPlan::Release] release Release
      # @param [String] name Template name
      def initialize(release, name)
        @release = release
        @name = name
        @model = nil
        @package_models = []
        @logger = Config.logger
      end

      # Looks up template model and its package models in DB
      # @return [void]
      def bind_models
        @model = @release.get_template_model_by_name(@name)

        if @model.nil?
          raise DeploymentUnknownTemplate, "Can't find template `#{@name}'"
        end

        @package_models = @model.package_names.map do |name|
          @release.get_package_model_by_name(name)
        end
      end

      # Downloads template blob to a given path
      # @return [String] Path to downloaded blob
      def download_blob
        uuid = UUIDTools::UUID.random_create
        path = File.join(Dir.tmpdir, "template-#{uuid}")

        if Config.blobstore.nil?
          raise DirectorError, "Blobstore is not initialized"
        end

        @logger.debug("Downloading template `#{@name}' (#{blobstore_id})...")
        t1 = Time.now

        File.open(path, "w") do |f|
          Config.blobstore.get(blobstore_id, f)
        end

        @logger.debug("Template `#{@name}' downloaded to #{path} " +
                      "(took #{Time.now - t1}s)")

        path
      end

      # @return [String]
      def version
        present_model.version
      end

      # @return [String]
      def sha1
        present_model.sha1
      end

      # @return [String]
      def blobstore_id
        present_model.blobstore_id
      end

      # @return [Array]
      def logs
        present_model.logs
      end

      private

      # Returns model only if it's present, fails otherwise
      # @return [Models::Template]
      def present_model
        if @model.nil?
          raise DirectorError, "Template `#{@name}' model is unbound"
        end
        @model
      end

    end
  end
end