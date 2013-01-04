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

      composite_blobstore(
          {
              :blobstores => {
                  :'1' => {
                      :provider => 'mock',
                      :options => {}
                  },
                  :'2' => {
                      :provider => 'mock',
                      :options => {}
                  }
              }
          })
    end

    it "raises an exception if no child clients were configured" do
      lambda { composite_blobstore({}) }.should raise_error(
          Bosh::Blobstore::BlobstoreError,
          'No blobstores were configured in options.')
    end

    it "raises an exception if less than two child clients were configured" do
      Bosh::Blobstore::Client.should_receive(:create).and_return('mock')

      lambda {
        composite_blobstore(
            {
                :blobstores => {
                    :'1' => {
                        :provider => 'mock',
                        :options => {}
                    }
                }
            })
      }.should raise_error(Bosh::Blobstore::BlobstoreError,
          'Less than two child blobstore clients were configured.')
    end

    it "raises an exception if no provider was specified for a client blobstore" do
      lambda {
        composite_blobstore(
            {
                :blobstores => {
                    :'1' => {
                        :options => {}
                    }
                }
            })
      }.should raise_error(Bosh::Blobstore::BlobstoreError,
          'provider not specified for a child blobstore client.')
    end
  end

  describe "operations" do

    before(:each) do
      @mock1 = double('mock1')
      @mock2 = double('mock2')

      opt1 = {
          :key1 => 'val1'
      }
      opt2 = {
          :key2 => 'val2'
      }

      Bosh::Blobstore::Client.should_receive(:create).with('mock1', opt1).
          and_return(@mock1)
      Bosh::Blobstore::Client.should_receive(:create).with('mock2', opt2).
          and_return(@mock2)
      @composite_bs = composite_blobstore(
          {
              :blobstores => {
                  :'2' => {
                      :provider => 'mock2',
                      :options => opt2
                  },
                  :'1' => {
                      :provider => 'mock1',
                      :options => opt1
                  }
              }
          })
    end

    describe "create_file" do

      it "should forward create_file call to first child" do
        @mock1.should_receive(:create_file).with('file')
        @composite_bs.create_file('file')
      end

      it "should raise an exception when there is an error creating an object" do
        @mock1.should_receive(:create_file).with('file').and_raise(
            Bosh::Blobstore::BlobstoreError)

        lambda {
          @composite_bs.create_file('file')
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

    end

    describe "delete_object" do

      it "should forward delete_object call to first child" do
        @mock1.should_receive(:delete_object).with('id')
        @composite_bs.delete_object('id')
      end

      it "should raise an exception when there is an error deleting an object" do
        @mock1.should_receive(:delete_object).with('id').and_raise(
            Bosh::Blobstore::BlobstoreError)

        lambda {
          @composite_bs.delete_object('id')
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

    end

    describe "get_file" do

      it "should forward get_file call to first child" do
        @mock1.should_receive(:get_file).with('id', 'file')
        @composite_bs.get_file('id', 'file')
      end

      it "should raise an exception when there is a general error fetching an object" do
        @mock1.should_receive(:get_file).and_raise(Bosh::Blobstore::BlobstoreError)
        lambda {
          @composite_bs.get_file('id', 'file')
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

      it "should forward get call to subsequent child client if first client raises NotFound" do
        @mock1.should_receive(:get_file).and_raise(Bosh::Blobstore::NotFound)
        @mock2.should_receive(:get_file).with('id', 'file')
        @composite_bs.get_file('id', 'file')
      end

      it "should raise a NotFound exception when the last child client raises a NotFound" do
        @mock1.should_receive(:get_file).and_raise(Bosh::Blobstore::NotFound)
        @mock2.should_receive(:get_file).and_raise(Bosh::Blobstore::NotFound)
        lambda {
          @composite_bs.get_file('id', 'file')
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end

    end

  end

end
