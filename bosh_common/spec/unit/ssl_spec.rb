require 'spec_helper'
require 'common/ssl'
require 'tmpdir'

describe Bosh::Ssl::Certificate do
  let(:subject_name) { '/C=US/O=Pivotal/CN=myapp.foo.com' }
  let(:common_name) { 'myapp.foo.com' }
  let(:server_certificate) { described_class.new(key_path, certificate_path, common_name) }

  describe '#load_or_create' do
    context 'when the paths given do not exist' do
      let(:key_path) { File.join(Dir.tmpdir, 'ca.key') }
      let(:certificate_path) { File.join(Dir.tmpdir, 'ca.pem') }

      context 'when the key exists but the certificate does not' do
        let(:key_path) { asset('ca/ca.key') }

        before do
          FileUtils.rm_f(certificate_path)
        end

        it 'raises an error' do
          expect {
            server_certificate.load_or_create
          }.to raise_error(Bosh::Ssl::Certificate::MatchingFileNotFound, /The key that matches the given certificate could not be found\./)
        end
      end

      context 'when the certificate exists but the key does not' do
        let(:certificate_path) { asset('ca/ca.pem') }

        before do
          FileUtils.rm_f(key_path)
        end

        it 'raises an error' do
          expect {
            server_certificate.load_or_create
          }.to raise_error(Bosh::Ssl::Certificate::MatchingFileNotFound, /The certificate that matches the given key could not be found\./)
        end
      end

      context 'when both of the files do not exist' do
        before do
          FileUtils.rm_f(key_path)
          FileUtils.rm_f(certificate_path)
        end

        it 'returns self so that it can be appended on to the constructor easily' do
          server_certificate.load_or_create.should == server_certificate
        end

        it 'creates a new, valid certificate' do
          server_certificate.load_or_create

          key = OpenSSL::PKey::RSA.new(File.read(key_path))
          certificate = OpenSSL::X509::Certificate.new(File.read(certificate_path))

          key.to_s.should include('BEGIN RSA PRIVATE KEY')
          certificate.to_s.should include('BEGIN CERTIFICATE')

          certificate.verify(key).should be_true
        end

        it 'sets the subject from the domain we ask for' do
          server_certificate.load_or_create

          certificate = OpenSSL::X509::Certificate.new(File.read(certificate_path))
          certificate.subject.to_s.should == subject_name
        end

        it 'has a sensible certificate lifetime' do
          server_certificate.load_or_create

          certificate = OpenSSL::X509::Certificate.new(File.read(certificate_path))
          start_time = certificate.not_before
          end_time = certificate.not_after

          (end_time - start_time).should == ((3 * 365) + 1) * 24 * 60 * 60 # 3 Years and 1 Day
        end

        it 'should start being valid some time in the past' do
          server_certificate.load_or_create

          certificate = OpenSSL::X509::Certificate.new(File.read(certificate_path))
          start_time = certificate.not_before

          start_time.should < (Time.now - 60 * 60 * 12)
        end
      end
    end

    context 'when the paths given do exist' do
      let(:key_path) { asset('ca/ca.key') }
      let(:certificate_path) { asset('ca/ca.pem') }
      let(:common_name) { 'myapp.dev102.cf.com' }

      it 'loads the key and certificate from the files' do
        key_contents_before = File.read(key_path)
        certificate_contents_before = File.read(certificate_path)

        server_certificate.load_or_create

        server_certificate.key.should == key_contents_before
        server_certificate.certificate.should == certificate_contents_before
      end

      it 'does not write to the file unnecessarily' do
        File.should_not_receive(:write).with(any_args)
        server_certificate.load_or_create
      end

      context 'when the user has a certificate chain' do
        let(:chain_path) { asset('ca/chain.pem') }
        let(:server_certificate) { described_class.new(key_path, certificate_path, common_name, chain_path) }

        it 'allows the user to read the contents of the chain file' do
          server_certificate.load_or_create

          server_certificate.chain.should include "BEGIN CERTIFICATE"
        end
      end

      context 'when the user does not have a certificate chain' do
        let(:server_certificate) { described_class.new(key_path, certificate_path, common_name) }

        it 'the certificate chain should be nil' do
          server_certificate.load_or_create

          server_certificate.chain.should be_nil
        end
      end
    end
  end
end
