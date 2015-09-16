require 'spec_helper'
require 'bosh/registry/client'
require 'json'

describe Bosh::Registry::Client do

  let(:endpoint) { 'http://localhost:25001' }
  let(:user) { 'user' }
  let(:password) { 'password' }
  let(:httpclient) { double(HTTPClient) }
  let(:header) { { 'Accept' => 'application/json', 'Authorization' => 'Basic dXNlcjpwYXNzd29yZA=='} }
  let(:response) { double('response')}
  let(:settings) { {'settings' => {'foo' => 'bar'}} }
  let(:settings_json) { settings.to_json }

  subject { described_class.new(endpoint, user, password) }

  before do
    allow(HTTPClient).to receive(:new).and_return(httpclient)
  end

  describe '#update_settings' do
    it 'should raise an error when the settings is not a Hash' do
      expect {
        subject.update_settings('id', 'string')
      }.to raise_error ArgumentError
    end

    it 'should raise an error when the response is not 2xx' do
      allow(response).to receive(:status).and_return(404)
      allow(httpclient).to receive(:put).and_return(response)

      expect {
        subject.update_settings('id', {})
      }.to raise_error Bosh::Clouds::CloudError
    end

    it 'should return true when it created successfully' do
      allow(response).to receive(:status).and_return(201)
      allow(httpclient).to receive(:put).with(
          'http://localhost:25001/instances/id/settings',
          { :body => settings_json, :header => header }
      ).and_return(response)

      expect(subject.update_settings('id', settings)).to be(true)
    end

    it 'should return true when it updated successfully' do
      allow(response).to receive(:status).and_return(200)
      allow(httpclient).to receive(:put).with(
        'http://localhost:25001/instances/id/settings',
        { :body => settings_json, :header => header }
      ).and_return(response)

      expect(subject.update_settings('id', settings)).to be(true)
    end
  end

  describe '#read_settings' do
    it 'should raise an error when the returned data is not a Hash' do
      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:body).and_return('string')
      allow(httpclient).to receive(:get).and_return(response)

      expect {
        subject.read_settings('id')
      }.to raise_error Bosh::Clouds::CloudError
    end

    it 'should return the stored settings' do
      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:body).and_return('{"settings":"{\"foo\":\"bar\"}"}')
      allow(httpclient).to receive(:get).with(
          'http://localhost:25001/instances/id/settings',
          { :header => header }
      ).and_return(response)

      expect(subject.read_settings('id')).to eq({'foo' => 'bar'})
    end
  end

  describe '#delete_settings' do
    it 'should not raise an error when deleting settings returns 200' do
      allow(response).to receive(:status).and_return(200)
      allow(httpclient).to receive(:delete).with(
          'http://localhost:25001/instances/id/settings',
          { :header => header }
      ).and_return(response)

      expect {
        subject.delete_settings('id')
      }.to_not raise_error
    end

    it 'should not raise an error when deleting settings returns 404' do
      allow(response).to receive(:status).and_return(404)
      allow(httpclient).to receive(:delete).with(
          'http://localhost:25001/instances/id/settings',
          { :header => header }
      ).and_return(response)

      expect {
        subject.delete_settings('id')
      }.to_not raise_error
    end

    it 'should raise an error if attempting to delete settings does not return 200 or 404' do
      allow(response).to receive(:status).and_return(500)
      allow(httpclient).to receive(:delete).with(
          'http://localhost:25001/instances/id/settings',
          { :header => header }
      ).and_return(response)

      expect {
        subject.delete_settings('id')
      }.to raise_error Bosh::Clouds::CloudError
    end

    it 'should delete the settings' do
      allow(response).to receive(:status).and_return(200)
      allow(httpclient).to receive(:delete).with(
          'http://localhost:25001/instances/id/settings',
          { :header => header }
      ).and_return(response)

      expect(subject.delete_settings('id')).to be(true)
    end
  end

end
