module Bosh::AwsCliPlugin
  class ELB
    class BadCertificateError < RuntimeError;
    end

    def initialize(credentials)
      @aws_provider = AwsProvider.new(credentials)
    end

    def create(name, vpc, settings, certs)
      subnet_names = settings['subnets']
      subnet_ids = vpc.subnets.select { |k, v| subnet_names.include?(k) }.values
      security_group_name = settings['security_group']
      security_group_id = vpc.security_group_by_name(security_group_name).id
      options = {
        :listeners => [{
                         port: 80,
                         protocol: :http,
                         instance_port: 80,
                         instance_protocol: :http,
                       }],
        :subnets => subnet_ids,
        :security_groups => [security_group_id]
      }

      if settings['https']
        domain = settings['domain']
        cert_name = settings['ssl_cert']
        cert = certs[cert_name]
        dns_record = settings['dns_record']

        certificate = Bosh::Ssl::Certificate.new(cert['private_key_path'],
                                                 cert['certificate_path'],
                                                 "#{dns_record}.#{domain}",
                                                 cert['certificate_chain_path']
        ).load_or_create

        uploaded_cert = upload_certificate(cert_name, certificate)

        options[:listeners] << {
          :port => 443,
          :protocol => :https,
          :instance_port => 80,
          :instance_protocol => :http,
          # passing through 'ssl_certificate_id' is undocumented, but we're
          # working around a bug filed here: https://github.com/aws/aws-sdk-ruby/issues/216
          :ssl_certificate_id => uploaded_cert.arn
        }
      end

      Bosh::Common.retryable(tries: 15, on: AWS::ELB::Errors::CertificateNotFound) do
        aws_elb.load_balancers.create(name, options).tap do |new_elb|
          new_elb.configure_health_check({
                                           :healthy_threshold => 5,
                                           :unhealthy_threshold => 2,
                                           :interval => 5,
                                           :timeout => 2,
                                           :target => 'TCP:80'
                                         })
        end
      end
    end

    def names
      aws_elb.load_balancers.map(&:name)
    end

    def server_certificate_names
      aws_iam.server_certificates.map(&:name)
    end

    def delete_elbs
      aws_elb.load_balancers.each(&:delete)
      delete_server_certificates
    end

    def delete_server_certificates
      Bosh::Common.retryable(tries: 5, sleep: 2) do
        aws_iam.server_certificates.each(&:delete)
        aws_iam.server_certificates.to_a.empty?
      end
    end

    def find_by_name(name)
      aws_elb.load_balancers.find { |lb| lb.name == name }
    end

    private

    attr_reader :aws_provider

    def aws_iam
      aws_provider.iam
    end

    def aws_elb
      aws_provider.elb
    end

    def upload_certificate(name, cert)
      certificates = aws_iam.server_certificates
      options = {
        name: name,
        certificate_body: cert.certificate,
        private_key: cert.key
      }

      options[:certificate_chain] = cert.chain if cert.chain

      begin
        certificate = nil

        Bosh::Common.retryable(on: AWS::IAM::Errors::MalformedCertificate, tries: 10, sleep: 2) do
          begin
            certificate = certificates.upload(options)
            server_certificate_names.include? name
          rescue AWS::IAM::Errors::EntityAlreadyExists
            certificate = aws_iam.server_certificates[name]
            true
          end
        end

        certificate
      rescue AWS::IAM::Errors::MalformedCertificate => e
        certificate = cert.certificate
        private_key = cert.key
        message = "Certificate:\n#{certificate}\n\nPrivate Key:\n#{private_key}"
        raise BadCertificateError.new("Unable to upload ELB SSL Certificate: #{e.message}\n#{message}")
      end
    end
  end
end
