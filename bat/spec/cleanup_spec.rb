# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "cleanup" do
  it "should remove lingering things" do
    if bosh("delete deployment bat").exit_status == 0
      puts "deleted deployment"
    end

    if bosh("delete stemcell bosh-stemcell #{stemcell_version}").exit_status == 0
      puts "deleted stemcell"
    end
    if bosh("delete release bat").exit_status == 0
      puts "deleted release"
    end
  end
end
