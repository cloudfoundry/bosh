module Bosh::AwsCliPlugin
  class VpcDestroyer
    def initialize(ui, config)
      @ui = ui
      @credentials = config['aws']
    end

    def delete_all
      vpc_ids = ec2.vpcs.map(&:id)
      if vpc_ids.empty?
        @ui.say('No VPCs found')
        return
      end

      @ui.say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)
      @ui.say("VPCs:\n\t#{vpc_ids.join("\n\t")}")
      return unless @ui.confirmed?('Are you sure you want to delete all VPCs?')

      dhcp_options = []

      vpc_ids.each do |vpc_id|
        vpc = Bosh::AwsCliPlugin::VPC.find(ec2, vpc_id)
        if vpc.instances_count > 0
          raise "#{vpc.instances_count} instance(s) running in #{vpc.vpc_id} - delete them first"
        end
        
        next unless @ui.confirmed?("Do NOT delete your default VPC. Are you sure you want to delete #{vpc_id}")

        dhcp_options << vpc.dhcp_options

        vpc.delete_network_interfaces
        vpc.delete_security_groups
        ec2.delete_internet_gateways(ec2.internet_gateway_ids)
        vpc.delete_subnets
        vpc.delete_route_tables
        vpc.delete_vpc
      end

      dhcp_options.uniq(&:id).map(&:delete)
    end

    private

    def ec2
      @ec2 ||= Bosh::AwsCliPlugin::EC2.new(@credentials)
    end
  end
end
