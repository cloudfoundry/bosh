require 'spec_helper'

module Bosh
  module Director
    describe NatsClientCertGenerator do
      subject do
        NatsClientCertGenerator.new(logger )
      end

      let(:Config) {instance_double('Config')}

      shared_examples_for 'agents nats certificates generation' do
        it 'generates a valid certificate signed by the root ca' do
          result = subject.generate_nats_client_certificate 'test.123'
          expect(result[:cert].verify(root_public_key)).to be_truthy
        end

        it 'generates a valid certificate for client auth usage' do
          result = subject.generate_nats_client_certificate 'test.123'
          desired = OpenSSL::X509::ExtensionFactory.new.create_ext('extendedKeyUsage', 'clientAuth', true).to_s
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

      context 'when CA or Private Key are misconfigured' do
        before do
          allow(Config).to receive(:nats_client_ca_certificate_path).and_return(asset('nats/nats_ca_certificate.pem'))
          allow(Config).to receive(:nats_client_ca_private_key_path).and_return(asset('nats/nats_ca_private_key.pem'))
        end

        it 'throws an invalid CA error if ca private key path is nil' do
          allow(Config).to receive(:nats_client_ca_private_key_path).and_return(nil)

          expect{ subject }.to raise_error(
            DeploymentNATSClientCertificateGenerationError,
            'Client certificate generation error. Config for nats_client_ca_private_key_path is nil.')
        end

        it 'throws an invalid CA error if ca certificate path is nil' do
          allow(Config).to receive(:nats_client_ca_certificate_path).and_return(nil)

          expect{ subject }.to raise_error(
            DeploymentNATSClientCertificateGenerationError,
            'Client certificate generation error. Config for nats_client_ca_certificate_path is nil.')
        end

        it 'throws an invalid CA error if ca private key path is not found' do
          allow(Config).to receive(:nats_client_ca_private_key_path).and_return('/invalid/path')

          expect{ subject }.to raise_error(
            DeploymentNATSClientCertificateGenerationError,
            'Client certificate generation error. Config for nats_client_ca_private_key_path is not found.')
        end

        it 'throws an invalid CA error if ca certificate path is not found' do
          allow(Config).to receive(:nats_client_ca_certificate_path).and_return('/invalid/path')

          expect{ subject }.to raise_error(
            DeploymentNATSClientCertificateGenerationError,
            'Client certificate generation error. Config for nats_client_ca_certificate_path is not found.')
        end

        it 'throws an invalid CA error if an error occurs while loading the certificate' do
          allow(Config).to receive(:nats_client_ca_certificate_path).and_return(asset('nats/invalid_nats_ca_certificate.pem'))

          expect { subject }.to raise_error(DeploymentNATSClientCertificateGenerationError) do |error|
           expect(error.message).to include('Error occurred while loading CA Certificate to generate NATS Client certificates')
           expect(error.message).to include('OpenSSL::X509::CertificateError: nested asn1 error')
          end
        end

        it 'throws an invalid Private Key error if an error occurs while loading the certificate private key' do
          allow(Config).to receive(:nats_client_ca_private_key_path).and_return(asset('nats/invalid_nats_ca_certificate_private_key.pem'))

          expect { subject }.to raise_error(DeploymentNATSClientCertificateGenerationError) do |error|
            expect(error.message).to include('Error occurred while loading private key to generate NATS Client certificates')
            expect(error.message).to include('OpenSSL::PKey::RSAError: Neither PUB key nor PRIV key: nested asn1 error')
          end
        end

        context 'when the key does not correspond to the certificate passed' do
          before do
            allow(Config).to receive(:nats_client_ca_certificate_path).and_return(asset('nats/nats_ca_certificate.pem'))
            allow(Config).to receive(:nats_client_ca_private_key_path).and_return(asset('nats/one_off_intermediate_certificate_private_key.pem'))
          end

          it 'throws an error' do
            expect { subject }.to raise_error(DeploymentNATSClientCertificateGenerationError) do |error|
              expect(error.message).to include('NATS Client certificate generation error. CA Certificate/Private Key mismatch')
            end
          end
        end
      end

      context 'when the CA used to sign the agent NATS certificates is a ROOT CA' do
        let(:root_public_key) do
          priv_key = OpenSSL::PKey::RSA.new(File.read(asset('nats/nats_ca_private_key.pem')))
          priv_key.public_key
        end

        before do
          allow(Config).to receive(:nats_client_ca_certificate_path).and_return(asset('nats/nats_ca_certificate.pem'))
          allow(Config).to receive(:nats_client_ca_private_key_path).and_return(asset('nats/nats_ca_private_key.pem'))
        end

        it_behaves_like 'agents nats certificates generation'
      end


      context 'when the CA used to sign the agent certificates is an Intermediate CA' do
        let(:root_public_key) do
          priv_key = OpenSSL::PKey::RSA.new(File.read(asset('nats/one_off_intermediate_certificate_private_key.pem')))
          priv_key.public_key
        end

        before do
          allow(Config).to receive(:nats_client_ca_certificate_path).and_return(asset('nats/one_off_intermediate_certificate.pem'))
          allow(Config).to receive(:nats_client_ca_private_key_path).and_return(asset('nats/one_off_intermediate_certificate_private_key.pem'))
        end

        it_behaves_like 'agents nats certificates generation'
      end
    end
  end
end
