# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::JobPropertyCollection do

  def make_job(properties)
    mock(Bosh::Cli::JobBuilder, :properties => properties)
  end

  def make(job_builder, global_properties, job_properties = {}, mappings = {})
    Bosh::Cli::JobPropertyCollection.new(
      job_builder, global_properties, job_properties, mappings)
  end

  it "copies all properties from the manifest if no properties are defined" do
    manifest_properties = {
      "cc" => {
        "token" => "deadbeef",
        "foo" => %w(bar baz zaz)
      },
      "router" => {
        "token" => "zbb"
      },
      "empty" => {}
    }

    job_properties = {
      "cc" => {
        "secret" => "22"
      },
      "foo" => "bar"
    }

    pc = make(make_job({}), manifest_properties, job_properties)

    pc.to_hash.should == {
      "cc" => {
        "token" => "deadbeef",
        "foo" => %w(bar baz zaz),
        "secret" => "22"
      },
      "router" => {
        "token" =>  "zbb"
      },
      "empty" => {},
      "foo" => "bar"
    }
  end

  it "copies only needed properties if job properties are defined" do
    property_defs = {
      "cc.foo" => {},
      "router.token" => {},
      "router.user" => {"default" => "admin"}
    }

    manifest_properties = {
      "cc" => {
        "token" => "deadbeef",
        "foo" => %w(bar baz zaz)
      },
      "router" => {
        "token" => "zbb"
      }
    }

    job_properties = {
      "cc" => {"foo" => "bar"}
    }

    pc = make(make_job(property_defs), manifest_properties, job_properties)

    pc.to_hash.should == {
      "cc" => {"foo" => "bar"},
      "router" => {"token" => "zbb", "user" => "admin"}
    }
  end

  it "supports property mappings" do
    property_defs = {
      "db.user" => {},
      "db.password" => {},
      "token" => {}
    }

    properties = {
      "ccdb" => {
        "user" => "admin",
        "password" => "secret"
      },
      "router" => {"token" => "deadbeef"}
    }

    mappings = {
      "db" => "ccdb",
      "token" => "router.token"
    }

    pc = make(make_job(property_defs), properties, {}, mappings)

    pc.to_hash.should == {
      "db" => {
        "user" => "admin",
        "password" => "secret"
      },
      "token" => "deadbeef"
    }
  end

end