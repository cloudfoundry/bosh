module Bosh::Aws
  class ELB

    def initialize(credentials)
      @credentials = credentials
      @aws_elb = AWS::ELB.new(@credentials)
      @aws_iam = AWS::IAM.new(@credentials)
    end

    def create(name, vpc, settings, certs)
      subnet_names = settings["subnets"]
      subnet_ids = vpc.subnets.select { |k, v| subnet_names.include?(k) }.values
      security_group_name = settings["security_group"]
      security_group_id = vpc.security_group_by_name(security_group_name).id
      options = {
          :listeners => [{
                             :port => 80,
                             :protocol => :http,
                             :instance_port => 80,
                             :instance_protocol => :http,
                         }],
          :subnets => subnet_ids,
          :security_groups => [security_group_id]
      }

      if settings["https"]
        domain = settings["domain"]
        cert_name = settings["ssl_cert"]
        cert = certs[cert_name]
        dns_record = settings["dns_record"]

        certificate = Bosh::Aws::ServerCertificate.new(cert['private_key'],
                                                       cert['certificate'],
                                                       domain,
                                                       dns_record,
                                                       cert['certificate_chain']
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

      Bosh::Common.retryable(tries: 10, on: AWS::ELB::Errors::CertificateNotFound) do
        aws_elb.load_balancers.create(name, options).tap do |new_elb|
          new_elb.configure_health_check({
                                             :healthy_threshold => 5,
                                             :unhealthy_threshold => 2,
                                             :interval => 5,
                                             :timeout => 2,
                                             :target => "TCP:80"
                                         })
        end
      end
    end

    def names
      aws_elb.load_balancers.map(&:name)
    end

    def delete_elbs
      aws_elb.load_balancers.each(&:delete)
      Bosh::Common.retryable(tries: 5, sleep: 2) do
        aws_iam.server_certificates.each(&:delete)
        aws_iam.server_certificates.to_a.empty?
      end
    end

    private

    attr_reader :aws_iam, :aws_elb

    def upload_certificate(name, cert)
      certificates = aws_iam.server_certificates
      options = {
          name: name,
          certificate_body: cert.certificate,
          private_key: cert.key
      }

      options[:certificate_chain] = cert.chain if cert.chain

      begin
        certificates.upload(options)
      rescue AWS::IAM::Errors::MalformedCertificate => e
        err "Unable to upload ELB SSL Certificate: #{e.message}\n  #{options.inspect}"
      end
    end

  end
end