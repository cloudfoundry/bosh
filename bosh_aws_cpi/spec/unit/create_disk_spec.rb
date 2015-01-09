# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::AwsCloud::Cloud do

  let(:zones) { [double('us-east-1a', :name => 'us-east-1a')] }
  let(:volume) { double('volume', :id => 'v-foobar') }
  let(:instance) { double('instance', id: 'i-test', availability_zone: 'foobar-land') }

  before do
    Bosh::AwsCloud::ResourceWait.stub(:for_volume).with(volume: volume, state: :available)
    @cloud = mock_cloud do |_ec2, region|
      @ec2 = _ec2
      @ec2.volumes.stub(:create) { volume }
      region.stub(:availability_zones => zones)
      region.stub(instances: double('instances', :[] => instance))
    end
  end

  it 'creates an EC2 volume' do
    @cloud.create_disk(2048, {}).should == 'v-foobar'
    expect(@ec2.volumes).to have_received(:create) do |params|
      expect(params[:size]).to eq(2)
    end
  end

  it 'rounds up disk size' do
    @cloud.create_disk(2049, {})
    expect(@ec2.volumes).to have_received(:create) do |params|
      expect(params[:size]).to eq(3)
    end
  end

  it 'check min and max disk size' do
    expect {
      @cloud.create_disk(100, {})
    }.to raise_error(Bosh::Clouds::CloudError, /minimum disk size is 1 GiB/)

    expect {
      @cloud.create_disk(2000 * 1024, {})
    }.to raise_error(Bosh::Clouds::CloudError, /maximum disk size is 1 TiB/)
  end

  it 'puts disk in the same AZ as an instance' do
    @cloud.create_disk(1024, {}, 'i-test')

    expect(@ec2.volumes).to have_received(:create) do |params|
      expect(params[:availability_zone]).to eq('foobar-land')
    end
  end

  it 'should pick a random availability zone when no instance is given' do
    @cloud.create_disk(2048, {})
    expect(@ec2.volumes).to have_received(:create) do |params|
      expect(params[:availability_zone]).to eq('us-east-1a')
    end
  end

  context 'cloud properties' do
    describe 'volume type' do
      it 'defaults to standard' do
        @cloud.create_disk(2048, {})

        expect(@ec2.volumes).to have_received(:create) do |params|
          expect(params[:volume_type]).to eq('standard')
        end
      end

      it 'is pulled from cloud properties' do
        @cloud.create_disk(2048, { 'type' => 'gp2' })

        expect(@ec2.volumes).to have_received(:create) do |params|
          expect(params[:volume_type]).to eq('gp2')
        end
      end
    end

    describe 'encryption' do
      it 'defaults to unencrypted' do
        @cloud.create_disk(2048, {})

        expect(@ec2.volumes).to have_received(:create) do |params|
          expect(params[:encrypted]).to eq(false)
        end
      end

      it 'passes through encryped => true' do
        @cloud.create_disk(2048, { 'encrypted' => true })

        expect(@ec2.volumes).to have_received(:create) do |params|
          expect(params[:encrypted]).to eq(true)
        end
      end
    end
  end
end
