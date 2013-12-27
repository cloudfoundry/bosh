require 'spec_helper'

describe Bosh::CloudStackCloud::StemcellCreator do

  let(:stemcell_properties) do
    {
        "name" => "stemcell-name",
        "version" => "0.7.0",
        "infrastructure" => "cloudstack",
        "architecture" =>  "x86_64",
        "root_device_name" => "/dev/sda1"
    }
  end

  let(:cloud) {
    mock_cloud do |compute|
      compute.stub(:ostypes).and_return([double("type1", :description => 'Ubuntu 8.04 (64-bit)', :id => 1),
                                         double("type2", :description => 'Ubuntu 10.04 (64-bit)', :id => 2),
                                         double("type3", :description => 'Ubuntu 12.04 (64-bit)', :id => 3)])
    end
  }

  context "real" do
    let(:server) {
      stub_const('Fog::Compute::Cloudstack::Server', double("server_class"))
      double("server", :class => Fog::Compute::Cloudstack::Server,
                       :id => 's-xxxxxxxx') }
    let(:volume) { double("volume", :id => 'v-xxxxxxxx', :server => server, :service => cloud.compute) }
    let(:snapshot) { double("snapshot", :id => "snap-xxxxxxxx") }
    let(:device) { double("device") }
    let(:image) { double("image") }

    it "should create a real stemcell" do
      SecureRandom.stub(:hex).and_return("random")
      image.stub(:id).and_return("i-xxxxx")
      cloud.stub(:state_timeout_volume).and_return(100)

      image_params = {
          :displaytext => "stemcell-name 0.7.0",
          :name => "BOSH-random",
          :ostypeid => 2,
          :snapshotid => "snap-xxxxxxxx",
      }

      creator = described_class.new(cloud.compute.zones.first, stemcell_properties, cloud)
      creator.stub(:wait_resource).and_return(nil)

      creator.should_receive(:copy_root_image)
      volume.should_receive(:reload)
      cloud.should_receive(:detach_volume).with(server, volume)

      cloud.compute.snapshots.should_receive(:create).with({:volume_id => "v-xxxxxxxx"}).and_return(snapshot)
      creator.should_receive(:wait_resource).with(snapshot, :backedup, :state, false, 100)

      job = generate_job
      cloud.compute.should_receive(:create_template).with(image_params).and_return({"createtemplateresponse" => {"jobid" => "j-xxxxxx"}})
      cloud.compute.jobs.should_receive(:get).with("j-xxxxxx").and_return(job)
      creator.should_receive(:wait_job_volume).with(job)

      snapshot.should_receive(:destroy)

      cloud.compute.images.should_receive(:get).with("j-xxxxxx").and_return(image)
      job.should_receive(:job_result).and_return({"template" => {"id" => "j-xxxxxx"}})
      Bosh::CloudStackCloud::TagManager.should_receive(:tag).with(image, "Name", "stemcell-name 0.7.0")

      stemcell = creator.create(volume, device, "/path/to/image")
    end
  end

  describe "#image_params" do
    it "should construct correct image params" do
      SecureRandom.stub(:hex).and_return("random")
      params = described_class.new(cloud.compute.zones.first, stemcell_properties, cloud).image_params("id", cloud.compute)

      params[:displaytext].should == "stemcell-name 0.7.0"
      params[:name].should == "BOSH-random"
      params[:ostypeid].should == 2
      params[:snapshotid].should == "id"
    end
  end

  describe "#find_in_path" do
    it "should not find a missing file" do
      creator = described_class.new(cloud.compute.zones.first, stemcell_properties, cloud)
      creator.find_in_path("program-that-doesnt-exist").should be_nil
    end

    it "should find stemcell-copy-cloudstack" do
      creator = described_class.new(cloud.compute.zones.first, stemcell_properties, cloud)
      path = ENV["PATH"]
      path += ":#{File.expand_path('../../assets', __FILE__)}"
      creator.find_in_path("stemcell-copy-cloudstack", path).should_not be_nil
    end
  end

  describe '#copy_root_image' do
    let(:creator) do
      creator = described_class.new(cloud.compute.zones.first, stemcell_properties, cloud)
      creator.stub(:image_path => '/path/to/image')
      creator.stub(:device => '/dev/volume')
      creator
    end

    it 'should call stemcell-copy found in the PATH' do
      creator.stub(:find_in_path => '/path/to/stemcell-copy-cloudstack')
      result = double('result', :output => 'output')

      cmd = 'sudo -n /path/to/stemcell-copy-cloudstack /path/to/image /dev/volume 2>&1'
      creator.should_receive(:sh).with(cmd).and_return(result)

      creator.copy_root_image
    end

    it 'should call the bundled stemcell-copy if not found in the PATH' do
      creator.stub(:find_in_path => nil)
      result = double('result', :output => 'output')

      stemcell_copy = File.expand_path("../../../../bosh_cloudstack_cpi/scripts/stemcell-copy-cloudstack.sh", __FILE__)
      cmd = "sudo -n #{stemcell_copy} /path/to/image /dev/volume 2>&1"
      creator.should_receive(:sh).with(cmd).and_return(result)

      creator.copy_root_image
    end
  end

end
