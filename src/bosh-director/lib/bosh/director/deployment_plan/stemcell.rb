module Bosh::Director
  module DeploymentPlan
    class Stemcell
      extend ValidationHelper
      attr_reader :alias
      attr_reader :os
      attr_reader :name
      attr_reader :version
      attr_reader :api_version
      attr_reader :models
      attr_writer :deployment_model

      def self.parse(spec)
        name_alias = safe_property(spec, 'alias', class: String, optional: true)
        name = safe_property(spec, 'name', class: String, optional: true)
        os = safe_property(spec, 'os', class: String, optional: true)
        version = safe_property(spec, 'version', class: String)

        if name.nil? && os.nil?
          raise ValidationMissingField, "Required property 'os' or 'name' was not specified in object (#{spec})"
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

      def is_only_using_os?
        !@os.nil? && @name.nil?
      end

      def bind_model(deployment_model)
        raise DirectorError, 'Deployment not bound in the deployment plan' if deployment_model.nil?

        add_stemcell_models
        add_deployment_to_models(deployment_model)

        @deployment_model = deployment_model
      end

      def add_stemcell_models
        if is_only_using_os?
          @models = @manager.all_by_os_and_version(@os, @version)
          raise StemcellNotFound, "Stemcell version '#{@version}' for OS '#{@os}' doesn't exist" if models.empty?
        else
          @models = @manager.all_by_name_and_version(@name, @version)
          raise StemcellNotFound, "Stemcell '#{@name}/#{@version}' doesn't exist" if models.empty?
        end

        model = @models.first
        @name = model.name
        @os = model.operating_system
        @version = model.version
        @api_version = model.api_version
      end

      def add_deployment_to_models(deployment_model)
        @models.each do |model|
          model.add_deployment(deployment_model) unless model.deployments.include?(deployment_model)
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

      def spec(cpi = '')
        {
          'name' => cpi_stemcell_name(cpi),
          'version' => @version,
        }
      end

      def model_for_az(availability_zone, cloud_factory)
        raise 'please bind model first' if @models.nil?
        raise StemcellNotFound, 'No stemcell found' if @models.empty?

        # stemcell might have no AZ, pick default model then
        return model_for_default_cpi if availability_zone.nil?

        cpi_name = cloud_factory.get_name_for_az(availability_zone)

        # stemcell might have AZ without cpi, pick default model then
        return model_for_default_cpi if cpi_name.nil?

        model_for_cpi(cloud_factory.get_cpi_aliases(cpi_name))
      end

      private

      def cpi_stemcell_name(cpi)
        # When bind_model has not been called fall back to default behaviour
        return @name if @models.nil?

        cpi_stemcell = @models.find { |model| model.cpi == cpi }

        # when we can't find the stemcell, fall back to default behaviour
        return @name if cpi_stemcell.nil?

        cpi_stemcell.name
      end

      def model_for_default_cpi
        stemcell = @models.find { |sc| sc.cpi.blank? }
        raise StemcellNotFound, "Required stemcell #{spec} not found for default cpi, please upload again" if stemcell.nil?
        stemcell
      end

      def model_for_cpi(cpi_aliases)
        stemcell = @models.find { |m| m.cpi == cpi_aliases[0] }
        stemcell = @models.find { |m| cpi_aliases.include?(m.cpi) } if stemcell.nil? && cpi_aliases.length > 1
        if stemcell.nil?
          raise StemcellNotFound, "Required stemcell #{spec} not found for cpi #{cpi_aliases[0]}, please upload again"
        end
        stemcell
      end
    end
  end
end
