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
    before { allow(Bosh::Director::Config).to receive(:cloud).and_return(cloud) }
    # Bosh::Director::Config.stub(:base_dir).and_return(tmp_dir)

    context 'when the stemcell tarball is valid' do
      before do
        manifest = {
            "name" => "jeos",
            "version" => 5,
            "operating_system" => "jeos-5",
            "cloud_properties" => {"ram" => "2gb"},
            "sha1" => "shawone"
        }
        stemcell_contents = create_stemcell(manifest, "image contents")
        @stemcell_file = Tempfile.new("stemcell_contents")
        File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
      end
      after { FileUtils.rm_rf(@stemcell_file.path) }

      it "should upload a local stemcell" do
        expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
          contents = File.open(image) { |f| f.read }
          expect(contents).to eq("image contents")
          "stemcell-cid"
        end

        update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
        update_stemcell_job.perform

        stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
        expect(stemcell).not_to be_nil
        expect(stemcell.cid).to eq("stemcell-cid")
        expect(stemcell.sha1).to eq("shawone")
        expect(stemcell.operating_system).to eq("jeos-5")
      end

      it "should upload a remote stemcell" do
        expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
          contents = File.open(image) { |f| f.read }
          expect(contents).to eql("image contents")
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
        expect(stemcell).not_to be_nil
        expect(stemcell.cid).to eq("stemcell-cid")
        expect(stemcell.sha1).to eq("shawone")
      end

      it "should cleanup the stemcell file" do
        expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
          contents = File.open(image) { |f| f.read }
          expect(contents).to eql("image contents")
          "stemcell-cid"
        end

        update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
        update_stemcell_job.perform

        expect(File.exist?(@stemcell_file.path)).to be(false)
      end

      context 'when stemcell exists' do
        before do
          Bosh::Director::Models::Stemcell.make(:name => "jeos", :version => "5", :cid=>"old-stemcell-cid")
        end

        it "should fail without --fix option set" do
          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
          expect { update_stemcell_job.perform }.to raise_exception(Bosh::Director::StemcellAlreadyExists)
        end

        it 'should upload stemcell and update db with --fix option set' do
          expect(cloud).to receive(:create_stemcell).and_return "new-stemcell-cid"

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path, 'fix' => true)
          expect { update_stemcell_job.perform }.to_not raise_error

          stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
          expect(stemcell).not_to be_nil
          expect(stemcell.cid).to eq("new-stemcell-cid")
        end
      end

      it "should fail if cannot extract stemcell" do
        result = Bosh::Exec::Result.new("cmd", "output", 1)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

        expect {
          update_stemcell_job.perform
        }.to raise_exception(Bosh::Director::StemcellInvalidArchive)
      end
    end

    context 'when the stemcell metadata lacks a value for operating_system' do
      before do
        manifest = {
            "name" => "jeos",
            "version" => 5,
            "cloud_properties" => {"ram" => "2gb"},
            "sha1" => "shawone"
        }
        stemcell_contents = create_stemcell(manifest, "image contents")
        @stemcell_file = Tempfile.new("stemcell_contents")
        File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
      end

      it 'should not fail' do
        expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
          contents = File.open(image) { |f| f.read }
          expect(contents).to eql("image contents")
          "stemcell-cid"
        end

        update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

        expect { update_stemcell_job.perform }.not_to raise_error
      end
    end

    def create_stemcell(manifest, image)
      io = StringIO.new

      Archive::Tar::Minitar::Writer.open(io) do |tar|
        tar.add_file("stemcell.MF", {:mode => "0644", :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
        tar.add_file("image", {:mode => "0644", :mtime => 0}) { |os, _| os.write(image) }
      end

      io.close
      gzip(io.string)
    end
  end
end
