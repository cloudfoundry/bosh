require 'spec_helper'
require 'bosh/director/core/templates/job_schema_validator'

module Bosh::Director::Core::Templates
  describe JobSchemaValidator do
    describe 'validate_schema' do
      let(:job_name) { 'job_name' }
      let(:schema) do
        {
          "$schema" => "https://json-schema.org/draft/2020-12/schema",
          "type" => "object",
          "properties" => {
            "number_prop" => { "type" => "number" },
            "string_prop" => { "type" => "string" },
            "ipv4_prop" => { "type" => "string", "format" => "ipv4" },
          }
        }
      end

      it 'returns true when the properties are valid' do
        expect(JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: {'number_prop' => 1, 'string_prop' => "2"})).to be_truthy
      end

      it 'raises an error when the properties are invalid' do
        expect { JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: {'number_prop' => "1", 'string_prop' => "2"}) }.to raise_error("Error validating properties for #{job_name}\nvalue at `/number_prop` is not a number")
      end

      it 'includes multiple errors for invalid properties' do
        expect { JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: {'number_prop' => "1", 'string_prop' => 2}) }.to raise_error("Error validating properties for #{job_name}\nvalue at `/number_prop` is not a number\nvalue at `/string_prop` is not a string")
      end

      it 'validates ip addresses' do
        expect(JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: {'ipv4_prop' => "192.168.0.1"})).to be_truthy
        expect { JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: {'ipv4_prop' => "192.168.0.900"}) }.to raise_error("Error validating properties for #{job_name}\nvalue at `/ipv4_prop` does not match format: ipv4")
      end

      context 'when an unsupported schema is declared' do
        let(:schema) do
          {
            "$schema" => "https://json-schema.org/draft/2019-09/schema"
          }
        end

        it 'raises an error' do
          expect { JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: { 'anything' => "anything" }) }.to raise_error("Only https://json-schema.org/draft/2020-12/schema schema is currently supported")
        end
      end

      context 'when no schema is declared' do
        let(:schema) do
          {
            "type" => "object"
          }
        end

        it 'raises an error' do
          expect { JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: { 'anything' => "anything" }) }.to raise_error("You must declare your $schema draft version")
        end
      end

      context 'when the schema validates a certificate' do
        let(:schema) do
          {
            "$schema" => "https://json-schema.org/draft/2020-12/schema",
            "type" => "object",
            "properties" => {
              "cert_prop" => {
                "type" => "certificate",
              },
            }
          }
        end

        it 'validates the property includes a valid certificate' do
          certificate = generate_rsa_certificate
          expect(JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: {'cert_prop' => certificate[:cert_pem]})).to be_truthy
          expect { JobSchemaValidator.validate(job_name: job_name, schema: schema, properties: {'cert_prop' => "not_a_certificate"}) }.to raise_error("Error validating properties for #{job_name}\nvalue at `/cert_prop` is not a certificate")
        end
      end
    end
  end
end
