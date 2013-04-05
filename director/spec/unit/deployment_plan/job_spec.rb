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

  describe "parsing job spec" do

    before(:each) do
      @deployment = make_deployment("mycloud")
      @plan = make_plan(@deployment)
      @spec = make_spec
    end

    it "parses name" do
      job = described_class.new(@plan, @spec)
      job.parse_name
      job.name.should == "foobar"
    end

    it "parses release" do
      job = described_class.new(@plan, @spec)
      release = mock(BD::DeploymentPlan::Release)
      @plan.should_receive(:release).with("appcloud").and_return(release)
      job.parse_release
      job.release.should == release
    end

    it "complains about unknown release" do
      job = described_class.new(@plan, @spec)
      @plan.should_receive(:release).with("appcloud").and_return(nil)
      expect {
        job.parse_release
      }.to raise_error(BD::JobUnknownRelease)
    end

    it "parses a single template" do
      job = described_class.new(@plan, @spec)
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
      job = described_class.new(@plan, @spec)
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
      job = described_class.new(@plan, @spec)
      job.parse_disk
      job.persistent_disk.should == 300
    end

    it "uses 0 for persistent disk if not present" do
      job = described_class.new(@plan, @spec)
      job.parse_disk
      job.persistent_disk.should == 0
    end

    it "parses resource pool" do
      job = described_class.new(@plan, @spec)

      resource_pool = mock(BD::DeploymentPlan::ResourcePool)
      @plan.should_receive(:resource_pool).with("dea").and_return(resource_pool)

      job.parse_resource_pool
      job.resource_pool.should == resource_pool
    end

    it "complains about unknown resource pool" do
      job = described_class.new(@plan, @spec)

      @plan.should_receive(:resource_pool).with("dea").and_return(nil)

      expect {
        job.parse_resource_pool
      }.to raise_error(BD::JobUnknownResourcePool)
    end

    describe "binding properties" do
      let(:props) do
        {
            "cc_url" => "www.cc.com",
            "deep_property" => {
                "unneeded" => "abc",
                "dont_override" => "def"
            },
            "dea_max_memory" => 1024
        }
      end
      let(:foo_properties) do
        {
            "dea_min_memory" => {"default" => 512},
            "deep_property.dont_override" => {"default" => "ghi"},
            "deep_property.new_property" => {"default" => "jkl"}
        }
      end
      let(:bar_properties) do
        {"dea_max_memory" => {"default" => 2048}}
      end
      let(:job) { described_class.new(@plan, @spec) }

      before do
        @spec["properties"] = props
        @spec["template"] = %w(foo bar)

        release = mock(BD::DeploymentPlan::Release)

        @plan.stub(:properties).and_return(props)
        @plan.should_receive(:release).with("appcloud").and_return(release)

        release.should_receive(:use_template_named).with("foo")
        release.should_receive(:use_template_named).with("bar")

        release.should_receive(:template).with("foo").and_return(foo_template)
        release.should_receive(:template).with("bar").and_return(bar_template)

        job.parse_name
        job.parse_release
        job.parse_template
        job.parse_properties
      end

      context "when all the job specs (aka templates) specify properties" do
        let(:foo_template) { mock(BD::DeploymentPlan::Template, :properties => foo_properties) }
        let(:bar_template) { mock(BD::DeploymentPlan::Template, :properties => bar_properties) }

        before do
          job.bind_properties
        end

        it "should drop deployment manifest properties not specified in the job spec properties" do
          job.properties.should_not have_key "cc"
          job.properties["deep_property"].should_not have_key "unneeded"
        end

        it "should include properties that are in the job spec properties but not in the deployment manifest" do
          job.properties["dea_min_memory"].should == 512
          job.properties["deep_property"]["new_property"].should == "jkl"
        end

        it "should not override deployment manifest properties with job_template defaults" do
          job.properties["dea_max_memory"].should == 1024
          job.properties["deep_property"]["dont_override"].should == "def"
        end
      end

      context "when none of the job specs (aka templates) specify properties" do
        let(:foo_template) { mock(BD::DeploymentPlan::Template, :properties => nil) }
        let(:bar_template) { mock(BD::DeploymentPlan::Template, :properties => nil) }

        before do
          job.bind_properties
        end

        it "should use the properties specified throughout the deployment manifest" do
          job.properties.should == props
        end
      end

      context "when some job specs (aka templates) specify properties and some don't" do
        let(:foo_template) { mock(BD::DeploymentPlan::Template, :properties => nil) }
        let(:bar_template) { mock(BD::DeploymentPlan::Template, :properties => bar_properties) }

        it "should raise an error" do
          expect {
            job.bind_properties
          }.to raise_error(BD::JobIncompatibleSpecs, "Job `foobar' has specs with conflicting property definition styles" +
              " between its job spec templates.  This may occur if colocating jobs, one of which has a spec file" +
              " including `properties' and one which doesn't.")
        end
      end
    end

    describe "property mappings" do
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

        job = described_class.new(@plan, @spec)
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

        job = described_class.new(@plan, @spec)
        expect {
          job.parse_properties
        }.to raise_error(BD::JobInvalidPropertyMapping)
      end
    end
  end
end