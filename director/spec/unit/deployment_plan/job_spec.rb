# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::DeploymentPlan::Job do

  def make_spec
    {
      "name" => "foobar",
      "template" => "foo",
      "release" => "appcloud",
      "resource_pool" => "dea"
    }
  end

  def make_deployment(name)
    BD::Models::Deployment.make(:name => name)
  end

  def make_plan(deployment)
    mock(BD::DeploymentPlan, :model => deployment)
  end

  def make(deployment, job_spec)
    BD::DeploymentPlan::Job.new(deployment, job_spec)
  end

  describe "parsing job spec" do

    before(:each) do
      @deployment = make_deployment("mycloud")
      @plan = make_plan(@deployment)
      @spec = make_spec
    end

    it "parses name" do
      job = make(@plan, @spec)
      job.parse_name
      job.name.should == "foobar"
    end

    it "parses release" do
      job = make(@plan, @spec)
      release = mock(BD::DeploymentPlan::Release)
      @plan.should_receive(:release).with("appcloud").and_return(release)
      job.parse_release
      job.release.should == release
    end

    it "complains about unknown release" do
      job = make(@plan, @spec)
      @plan.should_receive(:release).with("appcloud").and_return(nil)
      expect {
        job.parse_release
      }.to raise_error(BD::JobUnknownRelease)
    end

    it "parses a single template" do
      job = make(@plan, @spec)
      release = mock(BD::DeploymentPlan::Release)
      template = mock(BD::DeploymentPlan::Template)

      @plan.should_receive(:release).with("appcloud").and_return(release)
      release.should_receive(:use_template_named).with("foo")
      release.should_receive(:template).with("foo").and_return(template)

      job.parse_release
      job.parse_template
      job.templates.should == [template]
    end

    it "parses multiple templates" do
      @spec["template"] = %w(foo bar)
      job = make(@plan, @spec)
      release = mock(BD::DeploymentPlan::Release)
      foo_template = mock(BD::DeploymentPlan::Template)
      bar_template = mock(BD::DeploymentPlan::Template)

      @plan.should_receive(:release).with("appcloud").and_return(release)

      release.should_receive(:use_template_named).with("foo")
      release.should_receive(:use_template_named).with("bar")

      release.should_receive(:template).with("foo").and_return(foo_template)
      release.should_receive(:template).with("bar").and_return(bar_template)

      job.parse_release
      job.parse_template
      job.templates.should == [foo_template, bar_template]
    end

    it "parses persistent disk if present" do
      @spec["persistent_disk"] = 300
      job = make(@plan, @spec)
      job.parse_disk
      job.persistent_disk.should == 300
    end

    it "uses 0 for persistent disk if not present" do
      job = make(@plan, @spec)
      job.parse_disk
      job.persistent_disk.should == 0
    end

    it "parses resource pool" do
      job = make(@plan, @spec)

      resource_pool = mock(BD::DeploymentPlan::ResourcePool)
      @plan.should_receive(:resource_pool).with("dea").and_return(resource_pool)

      job.parse_resource_pool
      job.resource_pool.should == resource_pool
    end

    it "complains about unknown resource pool" do
      job = make(@plan, @spec)

      @plan.should_receive(:resource_pool).with("dea").and_return(nil)

      expect {
        job.parse_resource_pool
      }.to raise_error(BD::JobUnknownResourcePool)
    end

    it "uses all deployment properties if at least one template model " +
       "has no properties defined" do
      props = {
        "cc" => {
          "token" => "deadbeef",
          "max_users" => 1024
        },
        "dea_max_memory" => 2048
      }

      @spec["properties"] = props
      @spec["template"] = %w(foo bar)

      bar_p = {
        "dea_max_memory" => {"default" => 1024}
      }

      release = mock(BD::DeploymentPlan::Release)
      foo_template = mock(BD::DeploymentPlan::Template, :properties => nil)
      bar_template = mock(BD::DeploymentPlan::Template, :properties => bar_p)

      @plan.stub!(:properties).and_return(props)
      @plan.should_receive(:release).with("appcloud").and_return(release)

      release.should_receive(:use_template_named).with("foo")
      release.should_receive(:use_template_named).with("bar")

      release.should_receive(:template).with("foo").and_return(foo_template)
      release.should_receive(:template).with("bar").and_return(bar_template)

      job = make(@plan, @spec)

      job.parse_release
      job.parse_template
      job.parse_properties
      job.bind_properties

      job.properties.should == props
    end

    it "only copies properties needed by templates into job properties" do
      props = {
        "cc" => {
          "token" => "deadbeef",
          "max_users" => 1024
        },
        "dea_max_memory" => 2048,
        "foo" => {
          "bar" => "baz",
          "baz" => "zazzle"
        },
        "test_hash" => {"a" => "b", "c" => "d"}
      }

      @spec["properties"] = props
      @spec["template"] = %w(foo bar)

      foo_p = {
        "cc.token" => {},
        "test.long.property.name" => {"default" => 33},
        "test_hash" => {}
      }

      bar_p = {
        "dea_max_memory" => {"default" => 1024},
        "big_bad_wolf" => {"default" => "foo"}
      }

      release = mock(BD::DeploymentPlan::Release)
      foo_template = mock(BD::DeploymentPlan::Template, :properties => foo_p)
      bar_template = mock(BD::DeploymentPlan::Template, :properties => bar_p)

      @plan.stub!(:properties).and_return(props)
      @plan.should_receive(:release).with("appcloud").and_return(release)

      release.should_receive(:use_template_named).with("foo")
      release.should_receive(:use_template_named).with("bar")

      release.should_receive(:template).with("foo").and_return(foo_template)
      release.should_receive(:template).with("bar").and_return(bar_template)

      job = make(@plan, @spec)

      job.parse_release
      job.parse_template
      job.parse_properties
      job.bind_properties

      job.properties.should == {
        "cc" => {
          "token" => "deadbeef"
        },
        "dea_max_memory" => 2048,
        "big_bad_wolf" => "foo",
        "test" => {
          "long" => {
            "property" => {
              "name" => 33
            }
          }
        },
        "test_hash" => {"a" => "b", "c" => "d"}
      }
    end

    it "supports property mappings" do
      props = {
        "ccdb" => {
          "user" => "admin",
          "password" => "12321",
          "unused" => "yada yada"
        },
        "dea" => {
          "max_memory" => 2048
        }
      }

      @spec["properties"] = props
      @spec["property_mappings"] = {"db" => "ccdb", "mem" => "dea.max_memory"}
      @spec["template"] = "foo"

      foo_p = {
        "db.user" => {"default" => "root"},
        "db.password" => {},
        "db.host" => {"default" => "localhost"},
        "mem" => {"default" => 256}
      }

      release = mock(BD::DeploymentPlan::Release)
      foo_template = mock(BD::DeploymentPlan::Template, :properties => foo_p)

      @plan.stub!(:properties).and_return(props)
      @plan.should_receive(:release).with("appcloud").and_return(release)

      release.should_receive(:template).with("foo").and_return(foo_template)
      release.should_receive(:use_template_named).with("foo")

      job = make(@plan, @spec)
      job.parse_release
      job.parse_template
      job.parse_properties
      job.bind_properties

      job.properties.should == {
        "db" => {
          "user" => "admin",
          "password" => "12321",
          "host" => "localhost"
        },
        "mem" => 2048,
      }
    end

    it "complains about unsatisfiable property mappings" do
      props = {"foo" => "bar"}

      @spec["properties"] = props
      @spec["property_mappings"] = {"db" => "ccdb"}

      @plan.stub!(:properties).and_return(props)

      job = make(@plan, @spec)
      expect {
        job.parse_properties
      }.to raise_error(BD::JobInvalidPropertyMapping)
    end

  end
end