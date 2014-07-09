require 'spec_helper'
require 'net/http'

describe Bosh::Director::Jobs::UpdateStemcell do
  describe 'Resque job class expectations' do
    let(:job_type) { :update_stemcell }
    it_behaves_like 'a Resque job'
  end

  describe '#perform' do
    let!(:tmp_dir) { Dir.mktmpdir("base_dir") }
    before { allow(Dir).to receive(:mktmpdir).and_return(tmp_dir) }
    after { FileUtils.rm_rf(tmp_dir) }

    let(:cloud) { instance_double('Bosh::Cloud') }
    before { Bosh::Director::Config.stub(:cloud).and_return(cloud) }
    # Bosh::Director::Config.stub(:base_dir).and_return(tmp_dir)

    before do
      stemcell_contents = create_stemcell("jeos", 5, {"ram" => "2gb"}, "image contents", "shawone")
      @stemcell_file = Tempfile.new("stemcell_contents")
      File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
    end
    after { FileUtils.rm_rf(@stemcell_file.path) }

    it "should upload a local stemcell" do
      cloud.should_receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
        contents = File.open(image) { |f| f.read }
        expect(contents).to eq("image contents")
        "stemcell-cid"
      end

      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
      update_stemcell_job.perform

      stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
      stemcell.should_not be_nil
      stemcell.cid.should == "stemcell-cid"
      stemcell.sha1.should == "shawone"
    end

    it "should upload a remote stemcell" do
      cloud.should_receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
        contents = File.open(image) { |f| f.read }
        contents.should eql("image contents")
        "stemcell-cid"
      end

      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new('fake-stemcell-url', {'remote' => true})
      expect(update_stemcell_job).to receive(:download_remote_file) do |resource, url, path|
        expect(resource).to eq('stemcell')
        expect(url).to eq('fake-stemcell-url')
        FileUtils.mv(@stemcell_file.path, path)
      end
      update_stemcell_job.perform

      stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
      stemcell.should_not be_nil
      stemcell.cid.should == "stemcell-cid"
      stemcell.sha1.should == "shawone"
    end

    it "should cleanup the stemcell file" do
      cloud.should_receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
        contents = File.open(image) { |f| f.read }
        contents.should eql("image contents")
        "stemcell-cid"
      end

      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
      update_stemcell_job.perform

      File.exist?(@stemcell_file.path).should be(false)
    end

    it "should fail if the stemcell exists" do
      Bosh::Director::Models::Stemcell.make(:name => "jeos", :version => "5")

      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

      lambda { update_stemcell_job.perform }.should raise_exception(Bosh::Director::StemcellAlreadyExists)
    end

    it "should fail if cannot extract stemcell" do
      result = Bosh::Exec::Result.new("cmd", "output", 1)
      Bosh::Exec.should_receive(:sh).and_return(result)

      update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

      expect {
        update_stemcell_job.perform
      }.to raise_exception(Bosh::Director::StemcellInvalidArchive)
    end

    def create_stemcell(name, version, cloud_properties, image, sha1)
      io = StringIO.new

      manifest = {
        "name" => name,
        "version" => version,
        "cloud_properties" => cloud_properties,
        "sha1" => sha1
      }

      Archive::Tar::Minitar::Writer.open(io) do |tar|
        tar.add_file("stemcell.MF", {:mode => "0644", :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
        tar.add_file("image", {:mode => "0644", :mtime => 0}) { |os, _| os.write(image) }
      end

      io.close
      gzip(io.string)
    end
  end
end
