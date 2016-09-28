module Bosh::Director
  module DeploymentPlan
    class Stemcell
      extend ValidationHelper
      include CloudFactoryHelper

      attr_reader :alias
      attr_reader :os
      attr_reader :name
      attr_reader :version
      attr_reader :models

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

        add_stemcell_models
        add_deployment_to_models(deployment_model)

        @deployment_model = deployment_model
      end

      def add_stemcell_models
        @models = is_using_os? ?
            @manager.all_by_os_and_version(@os, @version) :
            @manager.all_by_name_and_version(@name, @version)

        model = @models.first
        @name = model.name
        @os = model.operating_system
        @version = model.version
      end

      def add_deployment_to_models(deployment_model)
        @models.each do |model|
          unless model.deployments.include?(deployment_model)
            model.add_deployment(deployment_model)
          end
        end
      end

      def desc
        return nil unless @models
        @models.first.desc
      end

      def sha1
        return nil unless @models
        @models.first.sha1
      end

      def spec
        {
          "name" => @name,
          "version" => @version
        }
      end

      def cid_for_az(az)
        raise 'please bind model first' if @models.nil?
        raise StemcellNotFound, "No stemcell found" if @models.empty?
        return @models.first.cid unless uses_cpi_config?

        cpi = cloud_factory(@deployment_model).lookup_cpi_for_az(az)
        raise "CPI for AZ #{az} can not be found" if cpi.nil?

        stemcell = model_for_cpi(cpi)
        raise StemcellNotFound, "Required stemcell #{spec} not found on cpi #{cpi}, please upload again" if stemcell.nil?
        stemcell.cid
      end

      def uses_cpi_config?
        !@models.first.cpi.nil?
      end

      def model_for_cpi(cpi)
        @models.find{|model|model.cpi == cpi}
      end
    end
  end
end
