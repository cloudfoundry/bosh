require 'spec_helper'

describe Bosh::Cli::Command::Biff do
  let(:biff) { Bosh::Cli::Command::Biff.new }
  let(:template_file) { spec_asset("biff/good_simple_template.erb") }

  before(:all) do
    # Let us test all private methods. They are private because they are only used in the
    # binding.
    Bosh::Cli::Command::Biff.send(:public, *Bosh::Cli::Command::Biff.private_instance_methods)
  end

  after do
    biff.delete_temp_diff_files
  end

  describe "#biff" do
    context "with a good simple template" do
      it "throws an error when there is an IP out of range" do
        config_file = spec_asset("biff/ip_out_of_range.yml")
        biff.stub!(:deployment).and_return(config_file)
        lambda {
          biff.biff(template_file)
        }.should raise_error(
                     Bosh::Cli::CliError,
                     "IP range '2..9' is not within " +
                         "the bounds of network 'default', which only has 1 IPs.")
      end

      it "correctly generates a file and reports when there are no differences" do
        config_file = spec_asset("biff/good_simple_config.yml")
        golden_file = spec_asset("biff/good_simple_golden_config.yml")
        biff.stub!(:deployment).and_return(config_file)
        biff.should_receive(:say).with("No differences.").once

        biff.biff(template_file)
        biff.template_output.should == File.read(golden_file)
      end
    end

    context "with a network only template" do
      let(:template_file) { spec_asset("biff/network_only_template.erb") }

      it "asks whether you would like to keep the new file" do
        config_file = spec_asset("biff/ok_network_config.yml")
        biff.stub!(:deployment).and_return(config_file)
        biff.should_receive(:agree).with(
            "Would you like to keep the new version? [yn]").once.and_return(false)

        biff.biff(template_file)
      end

      it "deletes temporary files" do
        config_file = spec_asset("biff/ok_network_config.yml")
        biff.stub!(:deployment).and_return(config_file)
        biff.should_receive(:agree).and_return(false)
        # Twice because of after :each
        biff.should_receive(:delete_temp_diff_files).twice
        biff.biff(template_file)
      end

      it "throws an error when there is more than one subnet for default" do
        config_file = spec_asset("biff/multiple_subnets_config.yml")
        biff.stub!(:deployment).and_return(config_file)
        lambda {
          biff.biff(template_file)
        }.should raise_error(Bosh::Cli::CliError, "Biff doesn't know how to deal " +
            "with anything other than one subnet in default")
      end

      it "throws an error when the gateway is anything other than the first ip" do
        config_file = spec_asset("biff/bad_gateway_config.yml")
        biff.stub!(:deployment).and_return(config_file)
        lambda {
          biff.biff(template_file)
        }.should raise_error(Bosh::Cli::CliError, "Biff only supports " +
            "configurations where the gateway is the first IP (e.g. 172.31.196.1).")
      end

      it "throws an error when the range is not specified in the config" do
        config_file = spec_asset("biff/no_range_config.yml")
        biff.stub!(:deployment).and_return(config_file)
        lambda {
          biff.biff(template_file)
        }.should raise_error(Bosh::Cli::CliError, "Biff requires each network to " +
            "have range and dns entries.")
      end

      it "throws an error if there are no subnets" do
        config_file = spec_asset("biff/no_subnet_config.yml")
        biff.stub!(:deployment).and_return(config_file)
        lambda {
          biff.biff(template_file)
        }.should raise_error(Bosh::Cli::CliError, "You must have subnets in default")
      end
    end

    context "with a properties template" do
      let(:template_file) { spec_asset("biff/properties_template.erb") }

      it "outputs the required yaml when the input does not contain it" do
        config_file = spec_asset("biff/no_cc_config.yml")
        biff.stub!(:deployment).and_return(config_file)

        biff.should_receive(:say).with(
            "Could not find properties.cc.srv_api_uri.").once

        biff.should_receive(:say).with("'#{template_file}' has it but " +
                                           "'#{config_file}' does not.").once

        # Cannot use this because 1.8.7 does not preserve Hash order, so this string
        # can come back in any order.
        biff.should_receive(:say).with(/Add this to '':/).once

        lambda {
          biff.biff(template_file)
        }.should raise_error Bosh::Cli::CliError, "There were 1 errors."
      end
    end

    context "randomized strings" do
      let(:template_file) { spec_asset("biff/random_string_template.erb") }
      let(:config_file) { spec_asset("biff/random_string.yml") }

      before {
        biff.stub!(:deployment).and_return(config_file)
        biff.should_receive(:agree).with(
          "Would you like to keep the new version? [yn]").once.and_return(false)
      }

      subject {
        biff.biff(template_file)
        Psych.load(biff.template_output)['properties']
      }

      it "Generate a password and put it in" do
        expect(subject["defined_but_no_passwd"]["password"]).to_not be_nil
      end

      it "Retain an existing" do
        expect(subject["defined_with_passwd"]["password"]).to eq "passwd_set_in_yml"
      end

      it "Duplicate passwords with same name" do
        expect(subject["same_passwd"]["password"]).to eq subject["defined_but_no_passwd"]["password"]
      end
    end

  end

  context "with good_simple_config" do

    before do
      config_file = spec_asset("biff/good_simple_config.yml")
      biff.stub!(:deployment).and_return(config_file)
      biff.setup(template_file)
    end

    describe "#find_in" do
      it "finds the object path" do
        obj = {"path1" => {"path2" => {"path3" => 3}}}
        biff.find_in("path1.path2.path3", obj).should == 3
      end

      it "finds the object(boolean) path" do
        obj = {"path1" => {"path2" => {"path3" => false}}}
        biff.find_in("path1.path2.path3", obj).should == false
      end

      it "finds the object path in an array by the name key" do
        obj = {"by_key" => 1, "arr" => [{"name" => "by_name"}]}
        biff.find_in("arr.by_name", obj).should == {"name" => "by_name"}
      end

      it "doesn't find the object path" do
        obj = {"path1" => {"path2" => {"path_other" => 'not_found'}}}
        biff.find_in("path1.path2.path3", obj).should be_nil
      end
    end

    describe "#ip" do
      before do
        biff.ip_helper = ip_helper
      end

      context "when using a dynamic list of IPs" do
        let(:ip_helper) do
          {
              "default" => {"range" => NetAddr::CIDR.create("192.168.1.0/22")}
          }
        end

        it "allows ip_range to take negative ranges" do
          biff.ip_helper =
              biff.ip_range(-11..-2, "default").should == "192.168.3.245 - 192.168.3.254"
        end
      end

      context "when using a static list of IPs" do
        let(:ip_helper) do
          {
              "default" => {
                  "static" => [
                      NetAddr::CIDR.create("192.168.1.1"),
                      NetAddr::CIDR.create("192.168.1.2"),
                      NetAddr::CIDR.create("192.168.1.3")]
              }
          }
        end

        it "gets a range from a static ip list correctly" do
          biff.ip_range((1..2), "default.static").should ==
              "192.168.1.2 - 192.168.1.3"
        end

        it "gets an IP from a static ip list correctly" do
          biff.ip(0, "default.static").should == "192.168.1.1"
        end
      end
    end

    describe "#delete_all_except" do
      it "deletes all except one entry from a Hash" do
        obj = {"by_key" => 1, "arr" => [{"name" => "by_name"}]}
        biff.delete_all_except(obj, "by_key").should == {"by_key" => 1}
      end

      it "deletes all except one entry from a Array" do
        obj = [{"name" => "a"}, {"name" => "b"}, {"name" => "c"}]
        biff.delete_all_except(obj, "b").should == [{"name" => "b"}]
      end
    end
  end
end
