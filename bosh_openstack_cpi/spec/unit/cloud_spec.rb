# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do
  describe :new do
    let(:cloud_options) { mock_cloud_options }
    let(:openstack_parms) {
      {
        :provider => 'OpenStack',
        :openstack_auth_url => 'http://127.0.0.1:5000/v2.0/tokens',
        :openstack_username => 'admin',
        :openstack_api_key => 'nova',
        :openstack_tenant => 'admin',
        :openstack_region => 'RegionOne',
        :openstack_endpoint_type => nil,
        :connection_options => connection_options,
      }
    }
    let(:connection_options) { nil }
    let(:compute) { double('Fog::Compute') }
    let(:image) { double('Fog::Image') }

    it 'should create a Fog connection' do
      Fog::Compute.stub(:new).with(openstack_parms).and_return(compute)
      Fog::Image.should_receive(:new).with(openstack_parms).and_return(image)
      cloud = Bosh::Clouds::Provider.create(:openstack, cloud_options)

      expect(cloud.openstack).to eql(compute)
      expect(cloud.glance).to eql(image)
    end

    context 'with connection options' do
      let(:connection_options) {
        JSON.generate({
          'ssl_verify_peer' => false,
        })
      }

      it 'should add optional options to the Fog connection' do
        cloud_options['openstack']['connection_options'] = connection_options
        Fog::Compute.stub(:new).with(openstack_parms).and_return(compute)
        Fog::Image.should_receive(:new).with(openstack_parms).and_return(image)
        cloud = Bosh::Clouds::Provider.create(:openstack, cloud_options)

        expect(cloud.openstack).to eql(compute)
        expect(cloud.glance).to eql(image)
      end
    end
  end

  describe "creating via provider" do
    it "can be created using Bosh::Cloud::Provider" do
      Fog::Compute.stub(:new)
      Fog::Image.stub(:new)
      cloud = Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::OpenStackCloud::Cloud)
    end

    it "raises ArgumentError on initializing with blank options" do
    	options = Hash.new("options")
    	expect { 
    		Bosh::OpenStackCloud::Cloud.new(options)
    	}.to raise_error(ArgumentError, /Invalid OpenStack configuration/)
    end

    it "raises ArgumentError on initializing with non Hash options" do
    	options = "this is a string"
    	expect { 
    		Bosh::OpenStackCloud::Cloud.new(options)
    	}.to raise_error(ArgumentError, /Invalid OpenStack configuration/)
    end

    it "raises a CloudError exception if cannot connect to the OpenStack Compute API" do
      Fog::Compute.should_receive(:new).and_raise(Excon::Errors::Unauthorized, "Unauthorized")
      Fog::Image.stub(:new)
      expect {
        Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Unable to connect to the OpenStack Compute API. Check task debug log for details.")
    end

    it "raises a CloudError exception if cannot connect to the OpenStack Image Service API" do
      Fog::Compute.stub(:new)
      Fog::Image.should_receive(:new).and_raise(Excon::Errors::Unauthorized, "Unauthorized")
      expect {
        Bosh::Clouds::Provider.create(:openstack, mock_cloud_options)
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Unable to connect to the OpenStack Image Service API. Check task debug log for details.")
    end
  end
end
