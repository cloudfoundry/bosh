# Copyright (c) 2012 VMware, Inc.

require "spec_helper"

describe "cleanup" do
  def cleanup(command, message)
    if bosh(command).exit_status == 0
      puts message
    end
  rescue
    # do nothing
  end

  it "should remove lingering things" do
    cleanup("delete deployment bat", "deleted deployment")
    command = "delete stemcell bosh-stemcell #{stemcell_version}"
    cleanup(command, "deleted stemcell")
    cleanup("delete release bat", "deleted release")
  end
end
