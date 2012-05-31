# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::ConfigurationHasher do

  it "should hash a simple job" do
    template = Bosh::Director::Models::Template.make(:blobstore_id => "b_id")

    instance_spec = mock("instance_spec")
    template_spec = mock("template_spec", :template => template)
    job_spec = mock("job_spec")
    blobstore_client = mock("blobstore_client")

    template_spec.stub!(:blobstore_id).and_return("b_id")
    template_spec.stub!(:name).and_return("router")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance_spec])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:templates).and_return([template_spec])
    instance_spec.stub!(:index).and_return(0)
    instance_spec.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "monit file",
                                   {"test" => {"destination" => "test_dst", "contents" => "test contents"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end

    instance_spec.should_receive(:configuration_hash=).with("d4b58a62d2102a315f27bf8c41b4dfef672f785b")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash
  end

  it "should hash a job with two templtes" do
    template = Bosh::Director::Models::Template.make(:blobstore_id => "b_id")
    template2 = Bosh::Director::Models::Template.make(:blobstore_id => "b_id2")

    instance_spec = mock("instance_spec")
    template_spec = mock("template_spec", :template => template)
    template_spec2 = mock("template_spec", :template => template2)
    job_spec = mock("job_spec")
    blobstore_client = mock("blobstore_client")

    template_spec.stub!(:blobstore_id).and_return("b_id")
    template_spec.stub!(:name).and_return("router")
    template_spec2.stub!(:blobstore_id).and_return("b_id2")
    template_spec2.stub!(:name).and_return("dashboard")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance_spec])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:templates).and_return([template_spec, template_spec2])
    instance_spec.stub!(:index).and_return(0)
    instance_spec.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "monit file",
                                   {"test" => {"destination" => "test_dst", "contents" => "test contents"}})

    template_contents2 = create_job("foo", "monit file",
                                   {"test" => {"destination" => "test_dst", "contents" => "test contents2"}})


    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents2)
    end

    instance_spec.should_receive(:configuration_hash=).with("3de1e0ee201a592d1127d888d7ab1ab1dd4b2b7c")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash
  end

  it "should expose the job context to the templates" do
    template = Bosh::Director::Models::Template.make(:blobstore_id => "b_id")

    instance_spec = mock("instance_spec")
    template_spec = mock("template_spec", :template => template)
    job_spec = mock("job_spec")
    blobstore_client = mock("blobstore_client")

    template_spec.stub!(:name).and_return("router")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance_spec])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:templates).and_return([template_spec])
    instance_spec.stub!(:index).and_return(0)
    instance_spec.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "<%= name %> <%= index %> <%= properties.foo %> <%= spec.test %>",
                                   {"test" => {"destination" => "test_dst", "contents" => "<%= index %>"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end

    instance_spec.should_receive(:configuration_hash=).with("1ec0fb915dd041e4e121ccd1464b88a9aed1ee60")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash
  end

  it "should give helpful error messages" do
    template = Bosh::Director::Models::Template.make(:blobstore_id => "b_id")

    instance_spec = mock("instance_spec")
    template_spec = mock("template_spec", :template => template)
    job_spec = mock("job_spec")
    blobstore_client = mock("blobstore_client")

    template_spec.stub!(:name).and_return("router")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance_spec])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:templates).and_return([template_spec])
    instance_spec.stub!(:index).and_return(0)
    instance_spec.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "<%= name %>\n <%= index %>\n <%= properties.testing.foo %> <%= spec.test %>",
                                   {"test" => {"destination" => "test_dst", "contents" => "<%= index %>"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    lambda { configuration_hasher.hash }.should raise_error("Error filling in template router/monit:3 for " +
                                                                "foo/0: 'undefined method `foo' for nil:NilClass'")
  end

end
