# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::InstanceSpec do

  it "trusts current state to have current IP for dynamic network" do
    deployment = stub("deployment plan")

    network = BD::DeploymentPlan::DynamicNetworkSpec.new(deployment, {
      "name" => "net_a",
      "cloud_properties" => {
        "foo" => "bar"
      }
    })

    deployment.stub(:network).with("net_a").and_return(network)

    job = stub("job spec")
    job.stub(:instance_states).and_return({})
    job.stub(:default_network).and_return({})
    job.stub(:state).and_return("started")
    job.stub(:deployment).and_return(deployment)

    reservation = BD::NetworkReservation.
      new(:type => BD::NetworkReservation::DYNAMIC)

    network.reserve(reservation)

    instance = Bosh::Director::DeploymentPlan::InstanceSpec.new(job, 0)
    instance.add_network_reservation("net_a", reservation)

    instance.network_settings.should == {
      "net_a" => {
        "type" => "dynamic",
        "cloud_properties" => { "foo" => "bar" }
      }
    }

    net_a = {
      "type" => "dynamic",
      "ip" => "10.0.0.6",
      "netmask" => "255.255.255.0",
      "gateway" => "10.0.0.1",
      "cloud_properties" => { "bar" => "baz" }
    }

    instance.current_state = {
      "networks" => {
        "net_a" => net_a
      },
    }

    instance.network_settings.should == {
      "net_a" => net_a
    }
  end

end
