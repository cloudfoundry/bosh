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
    instance_spec.should_receive(:template_hashes=).with(
        {"router"=>"d4b58a62d2102a315f27bf8c41b4dfef672f785b"})

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash
  end

  it "should correctly hash a job with two templates and two instances" do
    template = Bosh::Director::Models::Template.make(:blobstore_id => "b_id")
    template2 = Bosh::Director::Models::Template.make(:blobstore_id => "b_id2")

    instance_spec = mock("instance_spec")
    instance_spec2 = mock("instance_spec")
    template_spec = mock("template_spec", :template => template)
    template_spec2 = mock("template_spec", :template => template2)
    job_spec = mock("job_spec")
    blobstore_client = mock("blobstore_client")

    template_spec.stub!(:blobstore_id).and_return("b_id")
    template_spec.stub!(:name).and_return("router")
    template_spec2.stub!(:blobstore_id).and_return("b_id2")
    template_spec2.stub!(:name).and_return("dashboard")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance_spec, instance_spec2])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:templates).and_return([template_spec, template_spec2])
    instance_spec.stub!(:index).and_return(0)
    instance_spec.stub!(:spec).and_return({"test" => "spec"})
    instance_spec2.stub!(:index).and_return(1)
    instance_spec2.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "monit file",
        {"test" => {"destination" => "test_dst",
            "contents" => "test contents index <%= index %>"}})

    template_contents2 = create_job("foo", "monit file",
        {"test" => {"destination" => "test_dst",
            "contents" => "test contents2 <%= index %>"}})


    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end
    blobstore_client.should_receive(:get).with("b_id2", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents2)
    end

    instance_spec.should_receive(:configuration_hash=).with(
        "9a01d5eaef2466439cf5f47c817917869bf7382b")
    instance_spec2.should_receive(:configuration_hash=).with(
        "1ac87f1ff406553944d7bf1e3dc2ad224d50cc80")
    instance_spec.should_receive(:template_hashes=).with(
        {"dashboard"=>"b22dc37828aa4596f715a4d1d9a77bc999fb0f68",
         "router"=>"cdb03dd7e933d087030dc734d7515c8715dfadc0"})
    instance_spec2.should_receive(:template_hashes=).with(
        {"dashboard"=>"a06db619abd6eaa32a5ec848894486f162ede0ad",
         "router"=>"924386b29900dccb55b7a559ce24b9c3c1c9eff0"})

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
    instance_spec.should_receive(:template_hashes=).with(
        {"router"=>"1ec0fb915dd041e4e121ccd1464b88a9aed1ee60"})
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
    lambda {
      configuration_hasher.hash
    }.should raise_error("Error filling in template `monit' for `foo/0' " +
                         "(line 3: undefined method `foo' for nil:NilClass)")
  end

end
