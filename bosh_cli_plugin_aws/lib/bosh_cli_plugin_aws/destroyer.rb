module Bosh::Aws
  class Destroyer
    def initialize(ui, config)
      @ui = ui
      @credentials = config['aws']
    end

    def ensure_not_production!
      ec2 = Bosh::Aws::EC2.new(@credentials)
      raise "#{ec2.instances_count} instance(s) running. This isn't a dev account (more than 20) please make sure you want to do this, aborting." if ec2.instances_count > 20
    end

    def delete_all_elbs
      elb = Bosh::Aws::ELB.new(@credentials)
      elb_names = elb.names
      if elb_names.any? && @ui.confirmed?("Are you sure you want to delete all ELBs (#{elb_names.join(', ')})?")
        elb.delete_elbs
      end
    end
  end
end
