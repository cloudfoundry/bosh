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

  def create_release(name, monit, configuration_files)
    io = StringIO.new

    manifest = {
      "name" => name,
      "configuration" => {}
    }

    configuration_files.each do |path, configuration_file|
      manifest["configuration"][path] = configuration_file["destination"]
    end

    Archive::Tar::Minitar::Writer.open(io) do |tar|
      tar.add_file("job.MF", {:mode => "0644", :mtime => 0}) {|os, _| os.write(manifest.to_yaml)}
      tar.add_file("monit", {:mode => "0644", :mtime => 0}) {|os, _| os.write(monit)}

      tar.mkdir("configuration", {:mode => "0755", :mtime => 0})
      configuration_files.each do |path, configuration_file|
        tar.add_file("configuration/#{path}", {:mode => "0644", :mtime => 0}) do |os, _|
          os.write(configuration_file["contents"])
        end
      end
    end

    io.close

    gzip(io.string)
  end

  it "should hash a simple job" do
    instance = mock("instance")
    job = mock("job")
    blobstore_client = mock("blobstore_client")

    job.stub!(:name).and_return("foo")
    job.stub!(:instances).and_return([instance])
    job.stub!(:properties).and_return({"foo" => "bar"})
    instance.stub!(:index).and_return(0)
    instance.stub!(:index).and_return(0)

    template_contents = create_release("foo", "monit file",
                                       {"test" => {"destination" => "test_dst", "contents" => "test contents"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id").and_return(template_contents)

    instance.should_receive(:configuration_hash=).with("fe041c2ddf59c5e2603ab137c05023b9d7c5b983")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job, "b_id")
    configuration_hasher.hash
  end

  it "should expose the job context to the templates" do
    instance = mock("instance")
    job = mock("job")
    blobstore_client = mock("blobstore_client")

    job.stub!(:name).and_return("foo")
    job.stub!(:instances).and_return([instance])
    job.stub!(:properties).and_return({"foo" => "bar"})
    instance.stub!(:index).and_return(0)

    template_contents = create_release("foo", "<%= name %> <%= index %> <%= properties.foo %>",
                                       {"test" => {"destination" => "test_dst", "contents" => "<%= index %>"}})

    Bosh::Director::Config.stub!(:blobstore).and_return(blobstore_client)
    blobstore_client.should_receive(:get).with("b_id").and_return(template_contents)

    instance.should_receive(:configuration_hash=).with("1c3819edb5214fd53026b09dc1e262158be3c828")

    configuration_hasher = Bosh::Director::ConfigurationHasher.new(job, "b_id")
    configuration_hasher.hash
  end

end