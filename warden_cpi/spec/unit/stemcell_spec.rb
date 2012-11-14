require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Cloud do

  before :each do
    @stemcell_root = Dir.mktmpdir("warden-cpi")

    options = {
      "stemcell" => {
      "root" => @stemcell_root,
    }
    }

    @cloud = Bosh::Clouds::Provider.create(:warden, options)
  end

  context "successful cases" do

    let(:image_path) { File.expand_path("../../assets/stemcell-warden-test.tgz", __FILE__) }

    it "can create stemcell" do
      stemcell_id = @cloud.create_stemcell(image_path, nil)

      Dir.chdir(@stemcell_root) do
        Dir.glob("*").should have(1).items
        Dir.glob("*").should include(stemcell_id)
      end
    end

    it "can delete stemcell" do
      Dir.chdir(@stemcell_root) do
        stemcell_id = @cloud.create_stemcell(image_path, nil)

        Dir.glob("*").should have(1).items
        Dir.glob("*").should include(stemcell_id)

        @cloud.delete_stemcell(stemcell_id)

        Dir.glob("*").should be_empty
      end
    end
  end

  context "failed cases" do

    let(:image_path) { File.expand_path("../../assets/stemcell-not-existed.tgz", __FILE__) }

    it "should raise error with bad image path" do
      expect {
        stemcell_id = @cloud.create_stemcell(image_path, nil)
      }.to raise_error Bosh::Clouds::CloudError
    end

  end
end
