# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::ConfigurationHasher do

  it "should hash a simple job" do
    template = Bosh::Director::Models::Template.make(:blobstore_id => "b_id")

    instance_spec = mock("instance_spec")
    template_spec = mock("template_spec", :template => template)
    job_spec = mock("job_spec")

    template_spec.stub!(:blobstore_id).and_return("b_id")
    template_spec.stub!(:name).and_return("router")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance_spec])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:template).and_return(template_spec)
    instance_spec.stub!(:index).and_return(0)
    instance_spec.stub!(:spec).and_return({"test" => "spec"})

    template_contents =
      create_job("foo", "monit file",
                 {"test" => {
                   "destination" => "test_dst",
                   "contents" => "test contents"}
                 })

    tmp_file = Tempfile.new("blob")
    File.open(tmp_file.path, "w") { |f| f.write(template_contents) }
    template_spec.should_receive(:download_blob).and_return(tmp_file.path)

    instance_spec.should_receive(:configuration_hash=).
      with("d4b58a62d2102a315f27bf8c41b4dfef672f785b")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash
  end

  it "should expose the job context to the templates" do
    template = Bosh::Director::Models::Template.make(:blobstore_id => "b_id")

    instance_spec = mock("instance_spec")
    template_spec = mock("template_spec", :template => template)
    job_spec = mock("job_spec")

    template_spec.stub!(:name).and_return("router")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance_spec])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:template).and_return(template_spec)
    instance_spec.stub!(:index).and_return(0)
    instance_spec.stub!(:spec).and_return({"test" => "spec"})

    text = "<%= name %> <%= index %> <%= properties.foo %> <%= spec.test %>"

    template_contents = create_job("foo",
                                   text,
                                   {"test" => {
                                     "destination" => "test_dst",
                                     "contents" => "<%= index %>"
                                   }})

    tmp_file = Tempfile.new("blob")
    File.open(tmp_file.path, "w") { |f| f.write(template_contents) }
    template_spec.should_receive(:download_blob).and_return(tmp_file.path)

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
    job_spec.stub!(:template).and_return(template_spec)
    instance_spec.stub!(:index).and_return(0)
    instance_spec.stub!(:spec).and_return({"test" => "spec"})

    text = "<%= name %>\n <%= index %>\n " +
           "<%= properties.testing.foo %> <%= spec.test %>"

    template_contents = create_job("foo",
                                   text,
                                   {"test" => {
                                     "destination" => "test_dst",
                                     "contents" => "<%= index %>"
                                   }})

    tmp_file = Tempfile.new("blob")
    File.open(tmp_file.path, "w") { |f| f.write(template_contents) }
    template_spec.should_receive(:download_blob).and_return(tmp_file.path)

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    lambda {
      configuration_hasher.hash
    }.should raise_error("Error filling in template `monit' for `foo/0' " +
                         "(line 3: undefined method `foo' for nil:NilClass)")
  end

end
