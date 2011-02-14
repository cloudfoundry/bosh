require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::ConfigurationHasher do

  it "should hash a simple job" do
    instance = Bosh::Director::Models::Instance.make
    template = Bosh::Director::Models::Template.make
    job_spec = mock("job_spec")
    blobstore_client = mock("blobstore_client")

    template.stub!(:blobstore_id).and_return("b_id")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:template).and_return(template)
    instance.stub!(:index).and_return(0)
    instance.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "monit file",
                                   {"test" => {"destination" => "test_dst", "contents" => "test contents"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end

    instance.should_receive(:configuration_hash=).with("d4b58a62d2102a315f27bf8c41b4dfef672f785b")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash
  end

  it "should expose the job context to the templates" do
    instance = Bosh::Director::Models::Instance.make
    template = Bosh::Director::Models::Template.make
    job_spec = mock("job_spec")
    blobstore_client = mock("blobstore_client")

    template.stub!(:blobstore_id).and_return("b_id")
    job_spec.stub!(:name).and_return("foo")
    job_spec.stub!(:instances).and_return([instance])
    job_spec.stub!(:properties).and_return({"foo" => "bar"})
    job_spec.stub!(:template).and_return(template)
    instance.stub!(:index).and_return(0)
    instance.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "<%= name %> <%= index %> <%= properties.foo %> <%= spec.test %>",
                                   {"test" => {"destination" => "test_dst", "contents" => "<%= index %>"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end

    instance.should_receive(:configuration_hash=).with("1ec0fb915dd041e4e121ccd1464b88a9aed1ee60")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job_spec)
    configuration_hasher.hash
  end

end
