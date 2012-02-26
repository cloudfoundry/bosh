require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::VmCreator do

  before(:each) do
    @cloud = mock("cloud")
    Bosh::Director::Config.stub!(:cloud).and_return(@cloud)

    @deployment = Bosh::Director::Models::Deployment.make

    @deployment_plan = mock("deployment_plan")
    @deployment_plan.stub!(:deployment).and_return(@deployment)
    @deployment_plan.stub!(:name).and_return("deployment_name")

    @stemcell = Bosh::Director::Models::Stemcell.make(:cid => "stemcell-id")

    @stemcell_spec = mock("stemcell_spec")
    @stemcell_spec.stub!(:stemcell).and_return(@stemcell)

    @resource_pool_spec = mock("resource_pool_spec")
    @resource_pool_spec.stub!(:deployment).and_return(@deployment_plan)
    @resource_pool_spec.stub!(:stemcell).and_return(@stemcell_spec)
    @resource_pool_spec.stub!(:name).and_return("test")
    @resource_pool_spec.stub!(:cloud_properties).and_return({"ram" => "2gb"})
    @resource_pool_spec.stub!(:env).and_return({})
    @resource_pool_spec.stub!(:spec).and_return({"name" => "foo"})

    @network_settings = {"network_a" => {"ip" => "1.2.3.4"}}
  end


  it "should create a vm" do

    @cloud.should_receive(:create_vm).with(kind_of(String), "stemcell-id", {"ram" => "2gb"}, @network_settings, nil, {})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                              @network_settings, nil, @resource_pool_spec.env)
    vm.deployment.should == @deployment
    Bosh::Director::Models::Vm.all.should == [vm]
  end

  it "should create vm with disk" do
    @cloud.should_receive(:create_vm).with(kind_of(String), "stemcell-id", {"ram" => "2gb"}, @network_settings, [99], {})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell, @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99), @resource_pool_spec.env)
  end

  it "should create credentials when encryption is enabled" do
    Bosh::Director::Config.encryption = true
    @cloud.should_receive(:create_vm).with(kind_of(String), "stemcell-id",
                                           {"ram" => "2gb"}, @network_settings, [99],
                                           {"bosh" =>
                                             { "credentials" =>
                                               { "crypt_key" => kind_of(String),
                                                 "sign_key" => kind_of(String)}}})

    vm = Bosh::Director::VmCreator.new.create(@deployment, @stemcell,
                                              @resource_pool_spec.cloud_properties,
                                              @network_settings, Array(99),
                                              @resource_pool_spec.env)

    Base64.strict_decode64(vm.credentials["crypt_key"]).should be_kind_of(String)
    Base64.strict_decode64(vm.credentials["sign_key"]).should be_kind_of(String)

    lambda {
      Base64.strict_decode64(vm.credentials["crypt_key"] + "foobar")
    }.should raise_error(ArgumentError, /invalid base64/)

    lambda {
      Base64.strict_decode64(vm.credentials["sign_key"] + "barbaz")
    }.should raise_error(ArgumentError, /invalid base64/)
  end
end
