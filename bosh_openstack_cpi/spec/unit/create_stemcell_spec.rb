# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  let(:image) { double("image", :id => "i-bar", :name => "i-bar") }
  let(:unique_name) { SecureRandom.uuid }

  before :each do
    @tmp_dir = Dir.mktmpdir
  end

  describe "Image upload based flow" do

    it "creates stemcell using a stemcell file" do
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "qcow2",
        :container_format => "bare",
        :location => "#{@tmp_dir}/root.img",
        :is_public => false
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:generate_unique_name).and_return(unique_name)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      cloud.should_receive(:wait_resource).with(image, :active)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "container_format" => "bare",
        "disk_format" => "qcow2"
      })

      sc_id.should == "i-bar"
    end

    it "creates stemcell using a remote stemcell file" do
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "qcow2",
        :container_format => "bare",
        :copy_from => "http://cloud-images.ubuntu.com/bosh/root.img",
        :is_public => false
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:generate_unique_name).and_return(unique_name)
      cloud.should_not_receive(:unpack_image)
      cloud.should_receive(:wait_resource).with(image, :active)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "container_format" => "bare",
        "disk_format" => "qcow2",
        "image_location" => "http://cloud-images.ubuntu.com/bosh/root.img"
      })

      sc_id.should == "i-bar"
    end

    it "sets image properties from cloud_properties" do
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "qcow2",
        :container_format => "bare",
        :location => "#{@tmp_dir}/root.img",
        :is_public => false,
        :properties => {
          :name => "stemcell-name",
          :version => "x.y.z",
          :os_type => "linux",
          :os_distro => "ubuntu",
          :architecture => "x86_64",
          :auto_disk_config => "true"
        }
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:generate_unique_name).and_return(unique_name)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      cloud.should_receive(:wait_resource).with(image, :active)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "name" => "stemcell-name",
        "version" => "x.y.z",
        "os_type" => "linux",
        "os_distro" => "ubuntu",
        "architecture" => "x86_64",
        "auto_disk_config" => "true",
        "foo" => "bar",
        "container_format" => "bare",
        "disk_format" => "qcow2",
      })

      sc_id.should == "i-bar"
    end

    it "sets stemcell visibility to public when required" do
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "qcow2",
        :container_format => "bare",
        :location => "#{@tmp_dir}/root.img",
        :is_public => true,
      }

      cloud_options = mock_cloud_options
      cloud_options["openstack"]["stemcell_public_visibility"] = true
      cloud = mock_glance(cloud_options) do |glance|
        glance.images.should_receive(:create).with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:generate_unique_name).and_return(unique_name)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      cloud.should_receive(:wait_resource).with(image, :active)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "container_format" => "bare",
        "disk_format" => "qcow2",
      })

      sc_id.should == "i-bar"
    end

    it "should throw an error for non existent root image in stemcell archive" do
      result = Bosh::Exec::Result.new("cmd", "output", 0)
      Bosh::Exec.should_receive(:sh).and_return(result)

      cloud = mock_glance

      File.stub(:exists?).and_return(false)

      expect {
        cloud.create_stemcell("/tmp/foo", {
          "container_format" => "bare",
          "disk_format" => "qcow2"
        })
      }.to raise_exception(Bosh::Clouds::CloudError, "Root image is missing from stemcell archive")
    end

    it "should fail if cannot extract root image" do
      result = Bosh::Exec::Result.new("cmd", "output", 1)
      Bosh::Exec.should_receive(:sh).and_return(result)

      cloud = mock_glance

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)

      expect {
        cloud.create_stemcell("/tmp/foo", {
          "container_format" => "ami",
          "disk_format" => "ami"
        })
      }.to raise_exception(Bosh::Clouds::CloudError,
                           "Extracting stemcell root image failed. Check task debug log for details.")
    end
  end
end
