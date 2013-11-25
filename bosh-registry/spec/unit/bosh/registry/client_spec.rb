require 'spec_helper'
require 'bosh/registry/client'
require 'json'

describe Bosh::Registry::Client do

  let(:endpoint) { 'http://localhost:25001' }
  let(:user) { 'user' }
  let(:password) { 'password' }
  let(:httpclient) { double(HTTPClient) }
  let(:header) { {"Accept" => 'application/json', "Authorization" => 'Basic dXNlcjpwYXNzd29yZA=='} }
  let(:response) { double('response')}
  let(:settings) { {'settings' => {'foo' => 'bar'}} }
  let(:settings_json) { settings.to_json }

  subject { described_class.new(endpoint, user, password) }

  before do
    HTTPClient.stub(new: httpclient)
  end

  describe '#update_settings' do
    it 'should raise an error when the settings is not a Hash' do
      expect {
        subject.update_settings('id', 'string')
      }.to raise_error ArgumentError
    end

    it 'should raise an error when the response is not 200' do
      response.stub(status: 404)
      httpclient.stub(put: response)

      expect {
        subject.update_settings('id', {})
      }.to raise_error Bosh::Clouds::CloudError
    end

    it 'should return true when it updated successfully' do
      response.stub(status: 200)
      httpclient.should_receive(:put).with(
          "http://localhost:25001/instances/id/settings",
          { :body => settings_json, :header => header }
      ).and_return(response)

      expect(subject.update_settings('id', settings)).to be(true)
    end
  end

  describe '#read_settings' do
    it 'should raise an error when the returned data is not a Hash' do
      response.stub(status: 200, body: 'string')
      httpclient.stub(get: response)

      expect {
        subject.read_settings('id')
      }.to raise_error Bosh::Clouds::CloudError
    end

    it 'should return the stored settings' do
      response.stub(status: 200, body: '{"settings":"{\"foo\":\"bar\"}"}')
      httpclient.should_receive(:get).with(
          "http://localhost:25001/instances/id/settings",
          { :header => header }
      ).and_return(response)

      expect(subject.read_settings('id')).to eq({'foo' => 'bar'})
    end
  end

  describe '#delete_settings' do
    it 'should raise an error if the settings could not deleted' do
      response.stub(status: 404)
      httpclient.stub(:delete).with(
          "http://localhost:25001/instances/id/settings",
          { :header => header }
      ).and_return(response)

      expect {
        subject.delete_settings('id')
      }.to raise_error Bosh::Clouds::CloudError
    end

    it 'should delete the settings' do
      response.stub(status: 200)
      httpclient.should_receive(:delete).with(
          "http://localhost:25001/instances/id/settings",
          { :header => header }
      ).and_return(response)

      expect(subject.delete_settings('id')).to be(true)
    end
  end

end
