require "spec_helper"

describe Bosh::AwsCloud::ManualNetwork do
  let(:network_spec) {{}}
  let(:ec2) {double("ec2")}
  let(:instance) {double("instance")}

  it "should set the IP in manual networking" do
    network_spec = {"ip"=>"172.20.214.10",
                    "netmask"=>"255.255.254.0",
                    "cloud_properties"=>{"subnet"=>"i-1234"},
                    "default"=>["dns", "gateway"],
                    "dns"=>["172.22.22.153"],
                    "gateway"=>"172.20.214.1",
                    "mac"=>"00:50:56:ae:90:ab"}
    sn = Bosh::AwsCloud::ManualNetwork.new("default", network_spec)

    sn.private_ip.should == "172.20.214.10"
  end
end