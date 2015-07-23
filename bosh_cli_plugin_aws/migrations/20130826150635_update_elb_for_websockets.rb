class UpdateElbForWebsockets < Bosh::AwsCliPlugin::Migration
  def execute
    validate_receipt

    vpc = Bosh::AwsCliPlugin::VPC.find(ec2, vpc_id)
    security_group = vpc.security_group_by_name(cfrouter_security_group_name)

    params = {"protocol" => "tcp", "ports" => "4443", "sources" => "0.0.0.0/0"}
    if WebSocketElbHelpers.authorize_ingress(security_group, params)
      WebSocketElbHelpers.record_ingress(vpc_receipt, cfrouter_security_group_name, params)
      save_receipt('aws_vpc_receipt', vpc_receipt)
    end

    cfrouter_elb = elb.find_by_name("cfrouter")

    params = {port: 443, protocol: :https}
    https_listener_server_certificate = WebSocketElbHelpers.find_server_certificate_from_listeners(cfrouter_elb, params)

    params = {port: 4443, protocol: :ssl, instance_port: 80, instance_protocol: :tcp, server_certificate: https_listener_server_certificate}
    WebSocketElbHelpers.create_listener(cfrouter_elb, params)
  end

  private

  def validate_receipt
    begin
      cfrouter_config
    rescue KeyError
      err("Unable to find `cfrouter' ELB configuration in AWS VPC Receipt")
    end

    begin
      cfrouter_security_group_name
    rescue KeyError
      err("Unable to find `cfrouter' ELB Security Group in AWS VPC Receipt")
    end

    begin
      vpc_id
    rescue KeyError
      err("Unable to find VPC ID in AWS VPC Receipt")
    end

  end

  def vpc_receipt
    @vpc_receipt ||= load_receipt('aws_vpc_receipt')
  end

  def cfrouter_config
    vpc_receipt.fetch('original_configuration').fetch('vpc').fetch('elbs').fetch('cfrouter')
  end

  def cfrouter_security_group_name
    cfrouter_config.fetch('security_group')
  end

  def vpc_id
    vpc_receipt.fetch('vpc').fetch('id')
  end

  class WebSocketElbHelpers
    def self.find_security_group_by_name(ec2, vpc_id, name)
      vpc = Bosh::AwsCliPlugin::VPC.find(ec2, vpc_id)
      security_group = vpc.security_group_by_name(name)

      err("AWS reports that security group #{name} does not exist") unless security_group
      security_group
    end

    def self.authorize_ingress(security_group, params)
      security_group.authorize_ingress(params['protocol'], params['ports'].to_i, params['sources'])
      true
    rescue AWS::EC2::Errors::InvalidPermission::Duplicate
      false
    end

    def self.record_ingress(vpc_receipt, security_group_name, params)
        receipt_security_groups = vpc_receipt['original_configuration']['vpc']['security_groups']
        receipt_router_security_group = receipt_security_groups.find{ |g| g['name'] == security_group_name}
        receipt_router_security_group['ingress'] << params
    end

    def self.find_server_certificate_from_listeners(elb, params)
      listener = elb.listeners.find {|l| l.port == params[:port] && l.protocol == params[:protocol] }

      err("Could not find listener with params `#{params.inspect}' on ELB `#{elb.name}'") unless listener
      err("Could not find server certificate for listener with params `#{params.inspect}' on ELB `#{elb.name}'") unless listener.server_certificate

      listener.server_certificate
    end

    def self.create_listener(elb, params)
      elb.listeners.create(params)
    end
  end
end
