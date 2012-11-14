require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Cloud do
  context "stemcell" do

    before :each do
      @stemcell_root = Dir.mktmpdir("warden-cpi")

      options = {
        "stemcell" => {
          "root" => @stemcell_root,
        }
      }

      @cloud = Bosh::Clouds::Provider.create(:warden, options)
    end

    let(:image_path) { File.expand_path("../../assets/stemcell-warden-test.tgz", __FILE__) }

    it "can create stemcell" do
      stemcell_id = @cloud.create_stemcell(image_path, nil)

      `ls #{@stemcell_root}`.strip.should == stemcell_id
    end

    it "can delete stemcell" do
      stemcell_id = @cloud.create_stemcell(image_path, nil)

      `ls #{@stemcell_root}`.strip.should == stemcell_id

      @cloud.delete_stemcell(stemcell_id)

      `ls #{@stemcell_root}`.strip.should == ""
    end
  end
end
