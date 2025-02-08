require 'json_schemer'

module Bosh::Director::Core::Templates

  class CustomType < JSONSchemer::Draft202012::Vocab::Validation::Type
    def error(formatted_instance_location:, **)
      case value
      when 'certificate'
        "value at #{formatted_instance_location} is not a certificate"
      else
        super
      end
    end

    def valid_type(type, instance)
      case type
      when 'certificate'
        return false unless instance.is_a?(String)
        return true if instance == ""
        begin
          OpenSSL::X509::Certificate.load(instance)
        rescue OpenSSL::X509::CertificateError
          false
        end
      else
        super
      end
    end
  end

  JSONSchemer::Draft202012::Vocab::VALIDATION['type'] = CustomType

  class JobSchemaValidator
    def self.validate(job_name:, schema:, properties:)
      raise "You must declare your $schema draft version" if schema['$schema'].blank?
      json_schemer_schema = JSONSchemer.schema(schema)
      raise "Only https://json-schema.org/draft/2020-12/schema schema is currently supported" unless json_schemer_schema.meta_schema.base_uri == JSONSchemer::Draft202012::BASE_URI
      errors = json_schemer_schema.validate(properties).map do |error|
        error['error']
      end
      return true if errors.empty?
      errors.unshift("Error validating properties for #{job_name}")
      raise errors.join("\n")
    end
  end
end

