module Bosh::Director
  module DeploymentPlan
    class Stemcell
      extend ValidationHelper

      attr_reader :alias
      attr_reader :os
      attr_reader :name
      attr_reader :version
      attr_reader :model

      def self.parse(spec)
        name_alias = safe_property(spec, "alias", :class => String, :optional => true)
        name = safe_property(spec, "name", :class => String, :optional => true)
        os = safe_property(spec, "os", :class => String, :optional => true)
        version = safe_property(spec, "version", :class => String)

        if name.nil? && os.nil?
          raise ValidationMissingField, "Required property 'os' or 'name' was not specified in object (#{spec})"
        end

        if !name.nil? && !os.nil?
          raise StemcellBothNameAndOS, "Properties 'os' and 'name' are both specified for stemcell, choose one. (#{spec})"
        end

        new(name_alias, name, os, version)
      end

      def initialize(name_alias, name, os, version)
        @alias = name_alias
        @name = name
        @os = os
        @version = version
        @manager = Api::StemcellManager.new
      end

      def is_using_os?
        !@os.nil? && @name.nil?
      end

      def bind_model(deployment_model)
        if deployment_model.nil?
          raise DirectorError, "Deployment not bound in the deployment plan"
        end

        add_stemcell_model

        unless @model.deployments.include?(deployment_model)
          @model.add_deployment(deployment_model)
        end
      end

      def add_stemcell_model
        @model = is_using_os? ?
          @manager.find_by_os_and_version(@os, @version) :
          @manager.find_by_name_and_version(@name, @version)

        @name = @model.name
        @os = @model.operating_system
        @version = @model.version
      end

      def desc
        @model.desc
      end

      def cid
        @model.cid
      end

      def id
        @model.id
      end

      def spec
        {
          "name" => @name,
          "version" => @version
        }
      end

    end
  end
end
