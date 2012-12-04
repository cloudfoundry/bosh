require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Cloud do

  before :each do
    @stemcell_root = Dir.mktmpdir("warden-cpi-stemcell")

    options = {
      "stemcell" => {
      "root" => @stemcell_root,
    }
    }

    @cloud = Bosh::Clouds::Provider.create(:warden, options)
  end

  after :each do
    FileUtils.rm_rf @stemcell_root
  end

  let(:image_path) { asset("stemcell-warden-test.tgz") }
  let(:bad_image_path) { asset("stemcell-not-existed.tgz") }

  context "create_stemcell" do

    it "can create stemcell" do
      stemcell_id = @cloud.create_stemcell(image_path, nil)

      Dir.chdir(@stemcell_root) do
        Dir.glob("*").should have(1).items
        Dir.glob("*").should include(stemcell_id)
      end
    end

    it "should raise error with bad image path" do
      expect {
        stemcell_id = @cloud.create_stemcell(bad_image_path, nil)
      }.to raise_error
    end

    it "should clean up after an error is raised" do
      Bosh::Exec.stub(:sh) do |cmd|
        `#{cmd}`
        raise "error"
      end

      Dir.chdir(@stemcell_root) do

        Dir.glob("*").should be_empty

        expect {
          stemcell_id = @cloud.create_stemcell(image_path, nil)
        }.to raise_error

        Dir.glob("*").should be_empty

      end

    end
  end

  context "delete_stemcell" do

    it "can delete stemcell" do
      Dir.chdir(@stemcell_root) do
        stemcell_id = @cloud.create_stemcell(image_path, nil)

        Dir.glob("*").should have(1).items
        Dir.glob("*").should include(stemcell_id)

        ret = @cloud.delete_stemcell(stemcell_id)

        Dir.glob("*").should be_empty
        ret.should be_nil
      end
    end

  end

end
