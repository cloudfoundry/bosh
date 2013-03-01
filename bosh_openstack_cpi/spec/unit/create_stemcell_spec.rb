# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  before :each do
    @tmp_dir = Dir.mktmpdir
  end

  describe "Image upload based flow" do

    it "creates stemcell using an image without kernel nor ramdisk" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      unique_name = UUIDTools::UUID.random_create.to_s
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "ami",
        :container_format => "ami",
        :location => "#{@tmp_dir}/root.img",
        :is_public => true
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).
          with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      cloud.should_receive(:generate_unique_name).and_return(unique_name)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "container_format" => "ami",
        "disk_format" => "ami"
      })

      sc_id.should == "i-bar"
    end

    it "creates stemcell using an image with kernel and ramdisk id's" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      unique_name = UUIDTools::UUID.random_create.to_s
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "ami",
        :container_format => "ami",
        :location => "#{@tmp_dir}/root.img",
        :is_public => true,
        :properties => {
          :kernel_id => "k-id",
          :ramdisk_id => "r-id",
        }
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).
          with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      cloud.should_receive(:generate_unique_name).and_return(unique_name)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "container_format" => "ami",
        "disk_format" => "ami",
        "kernel_id" => "k-id",
        "ramdisk_id" => "r-id",
        "kernel_file" => "kernel.img",
        "ramdisk_file" => "initrd.img"
      })

      sc_id.should == "i-bar"
    end

    it "creates stemcell using an image with kernel and ramdisk files" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      kernel = double("image", :id => "k-img-id", :name => "k-img-id")
      ramdisk = double("image", :id => "r-img-id", :name => "r-img-id")
      unique_name = UUIDTools::UUID.random_create.to_s
      kernel_params = {
        :name => "BOSH-#{unique_name}-AKI",
        :disk_format => "aki",
        :container_format => "aki",
        :location => "#{@tmp_dir}/kernel.img",
        :properties => {
          :stemcell => "BOSH-#{unique_name}",
        }
      }
      ramdisk_params = {
        :name => "BOSH-#{unique_name}-ARI",
        :disk_format => "ari",
        :container_format => "ari",
        :location => "#{@tmp_dir}/initrd.img",
        :properties => {
          :stemcell => "BOSH-#{unique_name}",
        }
      }
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "ami",
        :container_format => "ami",
        :location => "#{@tmp_dir}/root.img",
        :is_public => true,
        :properties => {
          :kernel_id => "k-img-id",
          :ramdisk_id => "r-img-id",
        }
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).
          with(kernel_params).and_return(kernel)
        glance.images.should_receive(:create).
          with(ramdisk_params).and_return(ramdisk)
        glance.images.should_receive(:create).
          with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      File.stub(:exists?).and_return(true)
      cloud.should_receive(:generate_unique_name).and_return(unique_name)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "container_format" => "ami",
        "disk_format" => "ami",
        "kernel_file" => "kernel.img",
        "ramdisk_file" => "initrd.img"
      })

      sc_id.should == "i-bar"
    end

    it "sets image properies from cloud_properties" do
      image = double("image", :id => "i-bar", :name => "i-bar")
      kernel = double("image", :id => "k-img-id", :name => "k-img-id")
      ramdisk = double("image", :id => "r-img-id", :name => "r-img-id")
      unique_name = UUIDTools::UUID.random_create.to_s
      kernel_params = {
        :name => "BOSH-#{unique_name}-AKI",
        :disk_format => "aki",
        :container_format => "aki",
        :location => "#{@tmp_dir}/kernel.img",
        :properties => {
          :stemcell => "BOSH-#{unique_name}",
        }
      }
      ramdisk_params = {
        :name => "BOSH-#{unique_name}-ARI",
        :disk_format => "ari",
        :container_format => "ari",
        :location => "#{@tmp_dir}/initrd.img",
        :properties => {
          :stemcell => "BOSH-#{unique_name}",
        }
      }
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => "ami",
        :container_format => "ami",
        :location => "#{@tmp_dir}/root.img",
        :is_public => true,
        :properties => {
          :kernel_id => "k-img-id",
          :ramdisk_id => "r-img-id",
          :stemcell_name => "bosh-stemcell",
          :stemcell_version => "x.y.z"
        }
      }

      cloud = mock_glance do |glance|
        glance.images.should_receive(:create).
          with(kernel_params).and_return(kernel)
        glance.images.should_receive(:create).
          with(ramdisk_params).and_return(ramdisk)
        glance.images.should_receive(:create).
          with(image_params).and_return(image)
      end

      Dir.should_receive(:mktmpdir).and_yield(@tmp_dir)
      cloud.should_receive(:unpack_image).with(@tmp_dir, "/tmp/foo")
      File.stub(:exists?).and_return(true)
      cloud.should_receive(:generate_unique_name).and_return(unique_name)

      sc_id = cloud.create_stemcell("/tmp/foo", {
        "name" => "bosh-stemcell",
        "version" => "x.y.z",
        "container_format" => "ami",
        "disk_format" => "ami",
        "kernel_file" => "kernel.img",
        "ramdisk_file" => "initrd.img"
      })

      sc_id.should == "i-bar"
    end

    it "should throw an error for non existent root image in stemcell archive" do
      begin 
        dir = Dir.mkdir("tmp")
        Dir.chdir 'tmp'    
   
        kernel_img = File.new('kernel.img', 'w')
        ramdisk_img = File.new('initrd.img', 'w')

        tgz = Zlib::GzipWriter.new(File.open('stemcell.tgz', 'wb'))
        array = ['kernel.img']
    
        Minitar.pack(array, tgz)
      
        cloud = mock_glance
        error_expected = "Root image is missing from stemcell archive"
        error_actual = ""
        begin
          cloud.create_stemcell("./stemcell.tgz", {
            "name" => "bosh-stemcell",
            "version" => "x.y.z",
            "container_format" => "ami",
            "disk_format" => "ami",
            "kernel_file" => "kernel.img",
            "ramdisk_file" => "initrd.img"
          })
        rescue Bosh::Clouds::CloudError => e
          error_actual  = e.to_s
        end
        error_actual.should eq(error_expected)
      ensure
        File.delete('kernel.img')
        File.delete('initrd.img')
        File.delete('stemcell.tgz')
        Dir.chdir '..'
        Dir.delete('tmp')
      end
    end

    it "should throw an error for non existent kernel image in stemcell archive" do
      begin 
        dir = Dir.mkdir("tmp")
        Dir.chdir 'tmp'    
        root_img = File.new('root.img','w') 
        if root_img
          root_img.syswrite("ABCDEF")
        end
        ramdisk_img = File.new('initrd.img', 'w')

        tgz = Zlib::GzipWriter.new(File.open('stemcell.tgz', 'wb'))
        array = ['root.img']
    
        Minitar.pack(array, tgz)
      
        cloud = mock_glance
        error_expected = "Kernel image kernel.img is missing from stemcell archive"
        error_actual = ""
        begin
          cloud.create_stemcell("./stemcell.tgz", {
            "name" => "bosh-stemcell",
            "version" => "x.y.z",
            "container_format" => "ami",
            "disk_format" => "ami",
            "kernel_file" => "kernel.img",
            "ramdisk_file" => "initrd.img"
          })
        rescue Bosh::Clouds::CloudError => e
          error_actual  = e.to_s
        end
        error_actual.should eq(error_expected)
      ensure
        File.delete('root.img')
        File.delete('initrd.img')
        File.delete('stemcell.tgz')
        Dir.chdir '..'
        Dir.delete('tmp')
      end
    end

    it "should throw an error for non existent ramdisk image in stemcell archive" do
      begin 
        dir = Dir.mkdir("tmp")
        Dir.chdir 'tmp'    
        root_img = File.new('root.img','w') 
        if root_img
          root_img.syswrite("ABCDEF")
        end

        tgz = Zlib::GzipWriter.new(File.open('stemcell.tgz', 'wb'))
        array = ['root.img']
    
        Minitar.pack(array, tgz)
      
        cloud = mock_glance
        error_expected = "Ramdisk image initrd.img is missing from stemcell archive"
        error_actual = ""
        begin
          cloud.create_stemcell("./stemcell.tgz", {
            "name" => "bosh-stemcell",
            "version" => "x.y.z",
            "container_format" => "ami",
            "disk_format" => "ami",
            #"kernel_file" => "kernel.img",
            "ramdisk_file" => "initrd.img"
          })
        rescue Bosh::Clouds::CloudError => e
          error_actual  = e.to_s
        end
        error_actual.should eq(error_expected)
      ensure
        File.delete('root.img')
        File.delete('stemcell.tgz')
        Dir.chdir '..'
        Dir.delete('tmp')
      end
    end
  end
end
