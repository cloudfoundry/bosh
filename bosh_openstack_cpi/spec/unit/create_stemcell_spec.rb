# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  let(:image) { double('image', :id => 'i-bar', :name => 'i-bar') }
  let(:unique_name) { SecureRandom.uuid }

  before { @tmp_dir = Dir.mktmpdir }

  describe 'Image upload based flow' do
    it 'creates stemcell using a stemcell file' do
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => 'qcow2',
        :container_format => 'bare',
        :location => "#{@tmp_dir}/root.img",
        :is_public => false
      }

      cloud = mock_glance do |glance|
        expect(glance.images).to receive(:create).with(image_params).and_return(image)
      end

      expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')
      expect(cloud).to receive(:wait_resource).with(image, :active)

      sc_id = cloud.create_stemcell('/tmp/foo', {
        'container_format' => 'bare',
        'disk_format' => 'qcow2'
      })

      expect(sc_id).to eq 'i-bar'
    end

    it 'creates stemcell using a remote stemcell file' do
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => 'qcow2',
        :container_format => 'bare',
        :copy_from => 'http://cloud-images.ubuntu.com/bosh/root.img',
        :is_public => false
      }

      cloud = mock_glance do |glance|
        expect(glance.images).to receive(:create).with(image_params).and_return(image)
      end

      expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to_not receive(:unpack_image)
      expect(cloud).to receive(:wait_resource).with(image, :active)

      sc_id = cloud.create_stemcell('/tmp/foo', {
        'container_format' => 'bare',
        'disk_format' => 'qcow2',
        'image_location' => 'http://cloud-images.ubuntu.com/bosh/root.img'
      })

      expect(sc_id).to eq 'i-bar'
    end

    it 'sets image properties from cloud_properties' do
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => 'qcow2',
        :container_format => 'bare',
        :location => "#{@tmp_dir}/root.img",
        :is_public => false,
        :properties => {
          :name => 'stemcell-name',
          :version => 'x.y.z',
          :os_type => 'linux',
          :os_distro => 'ubuntu',
          :architecture => 'x86_64',
          :auto_disk_config => 'true'
        }
      }

      cloud = mock_glance do |glance|
        expect(glance.images).to receive(:create).with(image_params).and_return(image)
      end

      expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')
      expect(cloud).to receive(:wait_resource).with(image, :active)

      sc_id = cloud.create_stemcell('/tmp/foo', {
        'name' => 'stemcell-name',
        'version' => 'x.y.z',
        'os_type' => 'linux',
        'os_distro' => 'ubuntu',
        'architecture' => 'x86_64',
        'auto_disk_config' => 'true',
        'foo' => 'bar',
        'container_format' => 'bare',
        'disk_format' => 'qcow2',
      })

      expect(sc_id).to eq 'i-bar'
    end

    it 'passes through whitelisted glance properties from cloud_properties to glance when making a stemcell' do
      extra_properties = {
        'name' => 'stemcell-name',
        'version' => 'x.y.z',
        'os_type' => 'linux',
        'os_distro' => 'ubuntu',
        'architecture' => 'x86_64',
        'auto_disk_config' => 'true',
        'foo' => 'bar',
        'container_format' => 'bare',
        'disk_format' => 'qcow2',
        'hw_vif_model' => 'fake-hw_vif_model',
        'hypervisor_type' => 'fake-hypervisor_type',
        'vmware_adaptertype' => 'fake-vmware_adaptertype',
        'vmware_disktype' => 'fake-vmware_disktype',
        'vmware_linked_clone' => 'fake-vmware_linked_clone',
        'vmware_ostype' => 'fake-vmware_ostype',
      }

      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => 'qcow2',
        :container_format => 'bare',
        :location => "#{@tmp_dir}/root.img",
        :is_public => false,
        :properties => {
          :name => 'stemcell-name',
          :version => 'x.y.z',
          :os_type => 'linux',
          :os_distro => 'ubuntu',
          :architecture => 'x86_64',
          :auto_disk_config => 'true',
          :hw_vif_model => 'fake-hw_vif_model',
          :hypervisor_type => 'fake-hypervisor_type',
          :vmware_adaptertype => 'fake-vmware_adaptertype',
          :vmware_disktype => 'fake-vmware_disktype',
          :vmware_linked_clone => 'fake-vmware_linked_clone',
          :vmware_ostype => 'fake-vmware_ostype',
        }
      }

      cloud = mock_glance do |glance|
        expect(glance.images).to receive(:create).with(image_params).and_return(image)
      end
      allow(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
      allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
      allow(cloud).to receive(:unpack_image)
      allow(cloud).to receive(:wait_resource)

      cloud.create_stemcell('/tmp/foo', extra_properties)
    end

    it 'sets stemcell visibility to public when required' do
      image_params = {
        :name => "BOSH-#{unique_name}",
        :disk_format => 'qcow2',
        :container_format => 'bare',
        :location => "#{@tmp_dir}/root.img",
        :is_public => true,
      }

      cloud_options = mock_cloud_options['properties']
      cloud_options['openstack']['stemcell_public_visibility'] = true
      cloud = mock_glance(cloud_options) do |glance|
        expect(glance.images).to receive(:create).with(image_params).and_return(image)
      end

      expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)
      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:unpack_image).with(@tmp_dir, '/tmp/foo')
      expect(cloud).to receive(:wait_resource).with(image, :active)

      sc_id = cloud.create_stemcell('/tmp/foo', {
        'container_format' => 'bare',
        'disk_format' => 'qcow2',
      })

      expect(sc_id).to eq 'i-bar'
    end

    it 'should throw an error for non existent root image in stemcell archive' do
      result = Bosh::Exec::Result.new('cmd', 'output', 0)
      expect(Bosh::Exec).to receive(:sh).and_return(result)

      cloud = mock_glance

      allow(File).to receive(:exists?).and_return(false)

      expect {
        cloud.create_stemcell('/tmp/foo', {
          'container_format' => 'bare',
          'disk_format' => 'qcow2'
        })
      }.to raise_exception(Bosh::Clouds::CloudError, 'Root image is missing from stemcell archive')
    end

    it 'should fail if cannot extract root image' do
      result = Bosh::Exec::Result.new('cmd', 'output', 1)
      expect(Bosh::Exec).to receive(:sh).and_return(result)

      cloud = mock_glance

      expect(Dir).to receive(:mktmpdir).and_yield(@tmp_dir)

      expect {
        cloud.create_stemcell('/tmp/foo', {
          'container_format' => 'ami',
          'disk_format' => 'ami'
        })
      }.to raise_exception(Bosh::Clouds::CloudError,
        'Extracting stemcell root image failed. Check task debug log for details.')
    end
  end
end
