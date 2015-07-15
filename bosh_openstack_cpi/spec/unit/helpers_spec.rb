# Copyright (c) 2012 Piston Cloud Computing, Inc.

require 'spec_helper'
require 'timecop'

describe Bosh::OpenStackCloud::Helpers do
  subject(:cloud) { mock_cloud }
  before { allow(cloud).to receive(:sleep) }

  let(:resource) { double('resource', id: 'foobar', reload: cloud) }
  before { allow(resource).to receive(:status).and_return(:start, :stop) }

  before(:each) do
    allow(Bosh::Clouds::Config).to receive(:task_checkpoint)
  end

  describe 'wait_resource' do
    it 'does not raise if one of the target states is reached' do
      expect {
        cloud.wait_resource(resource, [:stop, :deleted], :status, false)
      }.to_not raise_error
    end

    it 'waits for configured amount of time' do
      expect(cloud).to receive(:sleep).with(3)

      cloud.wait_resource(resource, [:stop, :deleted], :status, false)
    end

    context 'when the resource status never changes' do
      it 'times out' do
        start_time = Time.now
        timeout_time = start_time + cloud.state_timeout + 1
        Timecop.freeze(start_time)

        allow(resource).to receive(:status) do
          Timecop.freeze(timeout_time)
          :start
        end

        expect {
          cloud.wait_resource(resource, :stop, :status, false)
        }.to raise_error Bosh::Clouds::CloudError, /Timed out/
      end
    end

    context 'when the resource status is error' do
      before { allow(resource).to receive(:status).and_return(:error) }

      it 'raises Bosh::Clouds::CloudError' do
        expect {
          cloud.wait_resource(resource, :stop, :status, false)
        }.to raise_error Bosh::Clouds::CloudError, /state is error/
      end
    end

    context 'when the resource status is failed' do
      before { allow(resource).to receive(:status).and_return(:failed) }

      it 'raises Bosh::Clouds::CloudError' do
        expect {
          cloud.wait_resource(resource, :stop, :status, false)
        }.to raise_error Bosh::Clouds::CloudError, /state is failed/
      end
    end

    context 'when the resource status is killed' do
      before { allow(resource).to receive(:status).and_return(:killed) }

      it 'raises Bosh::Clouds::CloudError' do
        expect {
          cloud.wait_resource(resource, :stop, :status, false)
        }.to raise_error Bosh::Clouds::CloudError, /state is killed/
      end
    end

    context 'when the resource is not found' do
      before { allow(resource).to receive(:reload).and_return(nil) }

      it 'should raise Bosh::Clouds::CloudError if resource not found' do
        expect {
          cloud.wait_resource(resource, :deleted, :status, false)
        }.to raise_error Bosh::Clouds::CloudError, /Resource not found/
      end

      context 'when the resource does not need to be found' do
        it 'does not raise' do
          expect { cloud.wait_resource(resource, :deleted, :status, true) }.not_to raise_error
        end
      end
    end
  end

  describe 'with_openstack' do
    let(:openstack) { double('openstack') }

    context 'when openstack raises an unexpected exception' do
      before { allow(openstack).to receive(:servers).and_raise(NoMemoryError) }

      it 'raises the exception without waiting' do
        expect(cloud).not_to receive(:sleep)

        expect {
          cloud.with_openstack do
            openstack.servers
          end
        }.to raise_error(NoMemoryError)
      end
    end

    context 'when openstack raises ServiceUnavailable' do
      let(:headers) { {} }
      let(:body) do
        {
          'overLimit' => {
            'message' => 'No server is available to handle this request.',
            'code' => 503,
          }
        }
      end
      let(:response) { Excon::Response.new(body: JSON.dump(body), headers: headers) }

      before do
        allow(openstack).to receive(:servers) do
          # next time don't raise the same exception to avoid looping
          allow(openstack).to receive(:servers).and_return(nil)

          raise Excon::Errors::ServiceUnavailable.new('', '', response)
        end
      end

      it 'retries until the max number of retries is reached' do
        allow(openstack).to receive(:servers).exactly(11).times.
          and_raise(Excon::Errors::ServiceUnavailable.new('', '', response))
        expect(cloud).to receive(:sleep).with(3).exactly(10).times

        expect {
          cloud.with_openstack do
            openstack.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         'OpenStack API Service Unavailable error. Check task debug log for details.')

      end
    end

    context 'when openstack raises RequestEntityTooLarge' do
      let(:headers) { {} }
      let(:body) do
        {
          'overLimit' => {
            'message' => 'This request was rate-limited.',
            'code' => 413,
            'details' => 'Only 10 POST request(s) can be made to * every minute.'
          }
        }
      end
      let(:response) { Excon::Response.new(body: JSON.dump(body), headers: headers) }

      before do
        allow(openstack).to receive(:servers) do
          # next time don't raise the same exception to avoid looping
          allow(openstack).to receive(:servers).and_return(nil)

          raise Excon::Errors::RequestEntityTooLarge.new('', '', response)
        end
      end

      it 'retries after waiting a default number of seconds' do
        expect(cloud).to receive(:sleep).with(3)

        cloud.with_openstack do
          openstack.servers
        end
      end

      it 'retries until the max number of retries is reached' do
        allow(openstack).to receive(:servers).exactly(11).times.
          and_raise(Excon::Errors::RequestEntityTooLarge.new('', '', response))
        expect(cloud).to receive(:sleep).with(3).exactly(10).times

        expect {
          cloud.with_openstack do
            openstack.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         'OpenStack API Request Entity Too Large error. Check task debug log for details.')
      end

      context 'when the response includes a retryAfter in the body' do
        before { body['overLimit']['retryAfter'] = 5 }

        it 'retries after waiting the amount of seconds received at the response body' do
          expect(cloud).to receive(:sleep).with(5)

          cloud.with_openstack do
            openstack.servers
          end
        end
      end

      context 'when the response includes a Retry-After header' do
        before { headers['Retry-After'] = 5 }

        it 'retries after waiting the amount of seconds received in the Retry-After header' do
          expect(cloud).to receive(:sleep).with(5)

          cloud.with_openstack do
            openstack.servers
          end
        end
      end
    end

    context 'when openstack raises BadRequest' do
      context 'when the error includes a message' do
        before do
          response = Excon::Response.new(:body => JSON.dump({'badRequest' => {'message' => 'some-message'}}))
          expect(openstack).to receive(:servers).and_raise(Excon::Errors::BadRequest.new('', '', response))
        end

        it 'should raise a CloudError exception with OpenStack API message' do
          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError,
                           "OpenStack API Bad Request (some-message). Check task debug log for details.")
        end
      end

      context 'when the error does not include a message' do
        before do
          response = Excon::Response.new(:body => '')
          expect(openstack).to receive(:servers).and_raise(Excon::Errors::BadRequest.new('', '', response))
        end

        it 'should raise a CloudError exception without OpenStack API message' do
          expect {
            cloud.with_openstack do
              openstack.servers
            end
          }.to raise_error(Bosh::Clouds::CloudError,
                           'OpenStack API Bad Request. Check task debug log for details.')
        end
      end
    end

    context 'when openstack raises InternalServerError' do
      it 'should retry the max number of retries before raising a CloudError exception' do
        expect(openstack).to receive(:servers).exactly(11)
          .and_raise(Excon::Errors::InternalServerError.new('InternalServerError'))
        expect(cloud).to receive(:sleep).with(3).exactly(10)

        expect {
          cloud.with_openstack do
            openstack.servers
          end
        }.to raise_error(Bosh::Clouds::CloudError,
                         'OpenStack API Internal Server error. Check task debug log for details.')
      end
    end
  end

  describe 'parse_openstack_response' do
    it 'should return nil if response has no body' do
      response = Excon::Response.new()

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return nil if response has an empty body' do
      response = Excon::Response.new(:body => JSON.dump(''))

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return nil if response is not JSON' do
      response = Excon::Response.new(:body => 'foo = bar')

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return nil if response is no key is found' do
      response = Excon::Response.new(:body => JSON.dump({'foo' => 'bar'}))

      expect(cloud.parse_openstack_response(response, 'key')).to be_nil
    end

    it 'should return the contents if key is found' do
      response = Excon::Response.new(:body => JSON.dump({'key' => 'foo'}))

      expect(cloud.parse_openstack_response(response, 'key')).to eql('foo')
    end

    it 'should return the contents of the first key found' do
      response = Excon::Response.new(:body => JSON.dump({'key1' => 'foo', 'key2' => 'bar'}))

      expect(cloud.parse_openstack_response(response, 'key2', 'key1')).to eql('bar')
    end
  end
end
