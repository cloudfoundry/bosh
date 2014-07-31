require 'spec_helper'
require 'rack/test'

describe Bosh::Monitor::ApiController do
  include Rack::Test::Methods

  def app
    Bosh::Monitor::ApiController.new
  end

  let(:config) { class_double(Bosh::Monitor)  }
  let(:varz) { { 'deployments_count' => 1, 'agents_count' => 1 } }
  before { allow(config).to receive(:http_user).and_return('http_user') }
  before { allow(config).to receive(:http_password).and_return('http_password') }
  before { allow(config).to receive(:varz).and_return(varz) }
  before { stub_const("Bhm", config) }

  describe "/varz" do
    context "when using authorized credentials" do
      before { basic_authorize(config.http_user, config.http_password) }

      it 'returns Bhm.varz in JSON format' do
        get '/varz'
        last_response.body.should == Yajl::Encoder.encode(varz, :terminator => "\n")
      end
    end

    context "when using unauthorized credentials" do
      before { basic_authorize('unauthorized', 'user') }

      it 'returns 401' do
        get '/varz'
        last_response.status.should == 401
      end
    end
  end

  describe "/healthz" do
    it 'returns 200 OK' do
      get '/healthz'
      last_response.status.should == 200
    end
  end
end
