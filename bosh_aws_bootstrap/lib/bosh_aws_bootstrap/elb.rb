module Bosh::Aws
  class ELB

    def initialize(credentials)
      @aws_elb = AWS::ELB.new(credentials)
    end

    def create(name, vpc, settings)
      subnet_names = settings["subnets"]
      subnet_ids = vpc.subnets.select { |k, v| subnet_names.include?(k) }.values
      security_group_name = settings["security_group"]
      security_group_id = vpc.security_group_by_name(security_group_name).id
      aws_elb.load_balancers.create(name, {
          :listeners => [{
                             :port => 80,
                             :protocol => :http,
                             :instance_port => 80,
                             :instance_protocol => :http,
                         }],
          :subnets => subnet_ids,
          :security_groups => [security_group_id]
      }).tap do |new_elb|
        new_elb.configure_health_check({
                                           :healthy_threshold => 5,
                                           :unhealthy_threshold => 2,
                                           :interval => 5,
                                           :timeout => 2,
                                           :target => "TCP:80"
                                       })
      end
    end

    def names
      aws_elb.load_balancers.map(&:name)
    end

    def delete_elbs
      aws_elb.load_balancers.each(&:delete)
    end

    private

    def aws_elb
      @aws_elb
    end
  end
end