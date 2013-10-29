module Bosh::Aws
  class Destroyer
    def initialize(ui)
      @ui = ui
    end

    def delete_all_elbs(config)
      credentials = config['aws']
      elb = Bosh::Aws::ELB.new(credentials)
      elb_names = elb.names
      if elb_names.any? && @ui.confirmed?("Are you sure you want to delete all ELBs (#{elb_names.join(', ')})?")
        elb.delete_elbs
      end
    end
  end
end
