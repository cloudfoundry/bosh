# Copyright (c) 2013 FamilySearch

require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::CompositeBlobstoreClient do

  def composite_blobstore(options)
    Bosh::Blobstore::CompositeBlobstoreClient.new(options)
  end

  describe "options" do

    it "initializes all child clients" do
      Bosh::Blobstore::Client.should_receive(:create).with { |provider, options|
        provider.should == 'mock'
      }.twice

      composite_bs = composite_blobstore(
          {
              :blobstores => [
                  {
                      'provider' => 'mock',
                      'options' => {}
                  },
                  {
                      'provider' => 'mock',
                      'options' => {}
                  }
              ]
          })
      composite_bs.clients.length.should == 2
    end

    it "raises an exception if no child clients were configured" do
      lambda { composite_blobstore({}) }.should raise_error(Bosh::Blobstore::BlobstoreError, 'Less than two child blobstore clients were configured')
    end

    it "raises an exception if less than two child clients were configured" do
      Bosh::Blobstore::Client.should_receive(:create).and_return('mock')

      lambda {
        composite_blobstore(
            {
                :blobstores => [
                    {
                        'provider' => 'mock',
                        'options' => {}
                    }
                ]
            })
      }.should raise_error(Bosh::Blobstore::BlobstoreError, 'Less than two child blobstore clients were configured')
    end
  end

  describe "operations" do

    before(:each) do
      @mock1 = double('mock1')
      @mock2 = double('mock2')

      Bosh::Blobstore::Client.should_receive(:create).and_return(@mock1)
      Bosh::Blobstore::Client.should_receive(:create).and_return(@mock2)
      @composite_bs = composite_blobstore(
          {
              :blobstores => [
                  {
                      'provider' => 'mock1',
                      'options' => {}
                  },
                  {
                      'provider' => 'mock2',
                      'options' => {}
                  }
              ]
          })
    end

    describe "create" do

      it "should forward create call to first child" do
        @mock1.should_receive(:create).with('contents')
        @composite_bs.create('contents')
      end

      it "should raise an exception when there is an error creating an object" do
        @mock1.should_receive(:create).with('contents').and_raise(Bosh::Blobstore::BlobstoreError)

        lambda {
          @composite_bs.create('contents')
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

    end

    describe "delete" do

      it "should forward delete call to first child" do
        @mock1.should_receive(:delete).with('id')
        @composite_bs.delete('id')
      end

      it "should raise an exception when there is an error deleting an object" do
        @mock1.should_receive(:delete).with('id').and_raise(Bosh::Blobstore::BlobstoreError)

        lambda {
          @composite_bs.delete('id')
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

    end

    describe "fetch" do

      it "should forward get call to first child" do
        @mock1.should_receive(:get).with('id', 'file')
        @composite_bs.get('id', 'file')
      end

      it "should raise an exception when there is a general error fetching an object" do
        @mock1.should_receive(:get).and_raise(Bosh::Blobstore::BlobstoreError)
        lambda {
          @composite_bs.get('id', 'file')
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

      it "should forward get call to subsequent child client if first client raises NotFound" do
        @mock1.should_receive(:get).and_raise(Bosh::Blobstore::NotFound)
        @mock2.should_receive(:get).with('id', 'file')
        @composite_bs.get('id', 'file')
      end

      it "should raise a NotFound exception when the last child client raises a NotFound" do
        @mock1.should_receive(:get).and_raise(Bosh::Blobstore::NotFound)
        @mock2.should_receive(:get).and_raise(Bosh::Blobstore::NotFound)
        lambda {
          @composite_bs.get('id', 'file')
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

    end

  end

end
