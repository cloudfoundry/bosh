require 'spec_helper'
require 'timecop'

module Bosh
  module Director
    describe NatsClientCertGenerator do
      subject do
        NatsClientCertGenerator.new(logger )
      end

      let(:Config) {instance_double('Config')}

      context 'When generating a NATS certificate' do
        before do
          director_config = SpecHelper.spec_get_director_config
          allow(Config).to receive(:nats_client_ca_certificate_path).and_return(director_config['nats']['client_ca_certificate_path'])
          allow(Config).to receive(:nats_client_ca_private_key_path).and_return(director_config['nats']['client_ca_private_key_path'])
        end

        context 'When it is misconfigured' do
          it 'throws an invalid CA error if ca private key path is nil' do
            allow(Config).to receive(:nats_client_ca_private_key_path).and_return(nil)

            expect{ subject }.to raise_error(
              DeploymentGeneratorCAInvalid,
              'Client certificate generation error. Config for nats_client_ca_private_key_path is nil.')
          end

          it 'throws an invalid CA error if ca certificate path is nil' do
            allow(Config).to receive(:nats_client_ca_certificate_path).and_return(nil)

            expect{ subject }.to raise_error(
              DeploymentGeneratorCAInvalid,
              'Client certificate generation error. Config for nats_client_ca_certificate_path is nil.')
          end

          it 'throws an invalid CA error if ca private key path is not found' do
            allow(Config).to receive(:nats_client_ca_private_key_path).and_return('/invalid/path')

            expect{ subject }.to raise_error(
              DeploymentGeneratorCAInvalid,
              'Client certificate generation error. Config for nats_client_ca_private_key_path is not found.')
          end

          it 'throws an invalid CA error if ca certificate path is not found' do
            allow(Config).to receive(:nats_client_ca_certificate_path).and_return('/invalid/path')

            expect{ subject }.to raise_error(
              DeploymentGeneratorCAInvalid,
              'Client certificate generation error. Config for nats_client_ca_certificate_path is not found.')
          end
        end

        it 'generates a valid certificate signed by the root ca' do
          result = subject.generate_nats_client_certificate 'test.123'
          expect(result[:cert].verify result[:ca_key]).to be_truthy
        end

        it 'generates a valid certificate for client auth usage' do
          result = subject.generate_nats_client_certificate 'test.123'
          desired = OpenSSL::X509::ExtensionFactory.new.create_ext("extendedKeyUsage","clientAuth",true).to_s
          details = []
          result[:cert].extensions.each{ |ext| details.push(ext.to_s) }
          expect(details).to include(desired)
        end

        it 'includes the common name passed in, in the certificate' do
          result = subject.generate_nats_client_certificate 'test.123'
          expect(result[:cert].subject.to_a).to include(['CN','test.123',12])
        end

        it 'certs have different serial numbers' do
          result1 = subject.generate_nats_client_certificate 'test.123'
          result2 = subject.generate_nats_client_certificate 'test.456'
          expect(result1[:cert].serial).to_not eq(result2[:cert].serial)
        end

        it 'cert has 2 years validity' do
          result = subject.generate_nats_client_certificate 'test.123'
          expect(result[:cert].not_before + (2 * 365 * 24 * 60 * 60)).to eq(result[:cert].not_after)
        end

        it 'private_key is 3072 bit' do
          result = subject.generate_nats_client_certificate 'test.123'
          expect(result[:key].to_text).to match(/(3072 bit)/)
        end
      end
    end
  end
end
