require 'spec_helper'

describe Bosh::Cli::Command::Biff do

  before :each do
    # Let us test all private methods.
    Bosh::Cli::Command::Biff.send(:public,
      *Bosh::Cli::Command::Biff.private_instance_methods)
    @biff = Bosh::Cli::Command::Biff.new
  end

  after :each do
    @biff.delete_temp_diff_files
  end

  it "throws an error when there is more than one subnet for default" do
    config_file = spec_asset("biff/multiple_subnets_config.yml")
    template_file = spec_asset("biff/network_only_template.erb")
    @biff.stub!(:deployment).and_return(config_file)
    lambda {
      @biff.biff(template_file)
    }.should raise_error(RuntimeError, "Biff doesn't know how to deal with " +
        "anything other than one subnet in default")
  end

  it "throws an error when the gateway is anything other than the first ip" do
    config_file = spec_asset("biff/bad_gateway_config.yml")
    template_file = spec_asset("biff/network_only_template.erb")
    @biff.stub!(:deployment).and_return(config_file)
    lambda {
      @biff.biff(template_file)
    }.should raise_error(RuntimeError, "Biff only supports configurations " +
        "where the gateway is the first IP (e.g. 172.31.196.1).")
  end

  it "throws an error when the range is not specified in the config" do
    config_file = spec_asset("biff/no_range_config.yml")
    template_file = spec_asset("biff/network_only_template.erb")
    @biff.stub!(:deployment).and_return(config_file)
    lambda {
      @biff.biff(template_file)
    }.should raise_error(RuntimeError, "Biff requires each network to have " +
        "range and dns entries.")
  end

  it "throws an error if there are no subnets" do
    config_file = spec_asset("biff/no_subnet_config.yml")
    template_file = spec_asset("biff/network_only_template.erb")
    @biff.stub!(:deployment).and_return(config_file)
    lambda {
      @biff.biff(template_file)
    }.should raise_error(RuntimeError, "You must have subnets in default")
  end

  it "outputs the required yaml when the input does not contain it" do
    config_file = spec_asset("biff/no_cc_config.yml")
    template_file = spec_asset("biff/properties_template.erb")
    @biff.stub!(:deployment).and_return(config_file)

    @biff.should_receive(:say).with(
        "Could not find properties.cc.srv_api_uri.").once

    @biff.should_receive(:say).with("'#{template_file}' has it but " +
        "'#{config_file}' does not.").once

    # Cannot use this because 1.8.7 does not preserve Hash order, so this string
    # can come back in any order.
    @biff.should_receive(:say).with(/Add this to '':/).once

    #@biff.should_receive(:say).once

    @biff.should_receive(:say).with("There were 1 errors.").once

    @biff.biff(template_file)
  end

  it "correctly generates a file and reports when there are no differences" do
    config_file = spec_asset("biff/good_simple_config.yml")
    template_file = spec_asset("biff/good_simple_template.erb")
    golden_file = spec_asset("biff/good_simple_golden_config.yml")
    @biff.stub!(:deployment).and_return(config_file)
    @biff.should_receive(:say).with("No differences.").once

    @biff.biff(template_file)
    @biff.template_output.should == File.read(golden_file)
  end

  it "asks whether you would like to keep the new file" do
    config_file = spec_asset("biff/ok_network_config.yml")
    template_file = spec_asset("biff/network_only_template.erb")
    @biff.stub!(:deployment).and_return(config_file)
    @biff.should_receive(:agree).with(
        "Would you like to keep the new version? [yn]").once.and_return(false)

    @biff.biff(template_file)
  end

  it "deletes temporary files" do
    config_file = spec_asset("biff/ok_network_config.yml")
    template_file = spec_asset("biff/network_only_template.erb")
    @biff.stub!(:deployment).and_return(config_file)
    @biff.should_receive(:agree).and_return(false)
    # Twice because of after :each
    @biff.should_receive(:delete_temp_diff_files).twice
    @biff.biff(template_file)
  end

  it "finds the object path" do
    obj = { "path1" => {"path2" => {"path3" => 3}} }
    @biff.find_in("path1.path2.path3", obj).should == 3
  end

  it "finds the object(boolean) path" do
    obj = { "path1" => {"path2" => {"path3" => false}} }
    @biff.find_in("path1.path2.path3", obj).should == false
  end

  it "finds the object path in an array by the name key" do
    obj = { "by_key" => 1, "arr" => [{"name" => "by_name"}]}
    @biff.find_in("arr.by_name", obj).should == {"name" => "by_name"}
  end

  it "allows ip_range to take negative ranges" do
    @biff.ip_helper = {
        "default" => { "range" => NetAddr::CIDR.create("192.168.1.0/22") }
    }
    @biff.ip_range(-11..-2, "default").should == "192.168.3.245 - 192.168.3.254"
  end

  it "deletes all except one entry from a Hash" do
    obj = { "by_key" => 1, "arr" => [{"name" => "by_name"}]}
    @biff.delete_all_except(obj, "by_key").should == { "by_key" => 1 }
  end

  it "deletes all except one entry from a Array" do
    obj = [ {"name" => "a"}, {"name" => "b"}, {"name" => "c"}]
    @biff.delete_all_except(obj, "b").should == [ {"name" => "b"} ]
  end

  it "gets a range from a static ip list correctly" do
    @biff.ip_helper = {
      "default" => {
        "static" => [
          NetAddr::CIDR.create("192.168.1.1"),
          NetAddr::CIDR.create("192.168.1.2"),
          NetAddr::CIDR.create("192.168.1.3") ]
      }}
    @biff.ip_range((1..2), "default.static").should ==
        "192.168.1.2 - 192.168.1.3"
  end

  it "gets an IP from a static ip list correctly" do
    @biff.ip_helper = {
      "default" => {
        "static" => [
          NetAddr::CIDR.create("192.168.1.1"),
          NetAddr::CIDR.create("192.168.1.2"),
          NetAddr::CIDR.create("192.168.1.3") ]
      }}
    @biff.ip(0, "default.static").should == "192.168.1.1"
  end
end
