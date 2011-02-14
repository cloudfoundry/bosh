require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::ConfigurationHasher do

  def gzip(string)
    result = StringIO.new
    zio = Zlib::GzipWriter.new(result)
    zio.mtime = 1
    zio.write(string)
    zio.close
    result.string
  end

  def create_job(name, monit, configuration_files)
    io = StringIO.new

    manifest = {
      "name" => name,
      "templates" => {}
    }

    configuration_files.each do |path, configuration_file|
      manifest["templates"][path] = configuration_file["destination"]
    end

    Archive::Tar::Minitar::Writer.open(io) do |tar|
      tar.add_file("job.MF", {:mode => "0644", :mtime => 0}) {|os, _| os.write(manifest.to_yaml)}
      tar.add_file("monit", {:mode => "0644", :mtime => 0}) {|os, _| os.write(monit)}

      tar.mkdir("templates", {:mode => "0755", :mtime => 0})
      configuration_files.each do |path, configuration_file|
        tar.add_file("templates/#{path}", {:mode => "0644", :mtime => 0}) do |os, _|
          os.write(configuration_file["contents"])
        end
      end
    end

    io.close

    gzip(io.string)
  end

  it "should hash a simple job" do
    instance = mock("instance")
    template = mock("template")
    job = mock("job")
    blobstore_client = mock("blobstore_client")

    template.stub!(:blobstore_id).and_return("b_id")
    job.stub!(:name).and_return("foo")
    job.stub!(:instances).and_return([instance])
    job.stub!(:properties).and_return({"foo" => "bar"})
    job.stub!(:template).and_return(template)
    instance.stub!(:index).and_return(0)
    instance.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "monit file",
                                   {"test" => {"destination" => "test_dst", "contents" => "test contents"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end

    instance.should_receive(:configuration_hash=).with("d4b58a62d2102a315f27bf8c41b4dfef672f785b")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job)
    configuration_hasher.hash
  end

  it "should expose the job context to the templates" do
    instance = mock("instance")
    template = mock("template")
    job = mock("job")
    blobstore_client = mock("blobstore_client")

    template.stub!(:blobstore_id).and_return("b_id")
    job.stub!(:name).and_return("foo")
    job.stub!(:instances).and_return([instance])
    job.stub!(:properties).and_return({"foo" => "bar"})
    job.stub!(:template).and_return(template)
    instance.stub!(:index).and_return(0)
    instance.stub!(:spec).and_return({"test" => "spec"})

    template_contents = create_job("foo", "<%= name %> <%= index %> <%= properties.foo %> <%= spec.test %>",
                                   {"test" => {"destination" => "test_dst", "contents" => "<%= index %>"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id", an_instance_of(File)).and_return do |_, file|
      file.write(template_contents)
    end

    instance.should_receive(:configuration_hash=).with("1ec0fb915dd041e4e121ccd1464b88a9aed1ee60")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job)
    configuration_hasher.hash
  end

end
