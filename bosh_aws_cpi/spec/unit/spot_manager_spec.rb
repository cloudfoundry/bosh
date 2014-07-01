require "spec_helper"

describe Bosh::AwsCloud::SpotManager do
  let(:region) { mock_ec2 }
  let(:spot_manager) { described_class.new(region) }

  let(:spot_instance_requests) do
    {
      :spot_instance_request_set => [ { :spot_instance_request_id=>"sir-12345c", :other_params_here => "which aren't used" } ], 
      :request_id => "request-id-12345"
    }
  end
  let(:instance) { double(AWS::EC2::Instance, id: 'i-12345678') }
  let(:aws_client) { double(AWS::EC2::Client) }

  before do
    allow(region).to receive(:client).and_return(aws_client)
    allow(region).to receive(:instances).and_return( {'i-12345678' => instance } )

    # Override total_spot_instance_request_wait_time to be "unit test" speed
    allow(spot_manager).to receive(:total_spot_instance_request_wait_time).and_return(0.1)
  end

  it "should wait total_spot_instance_request_wait_time() seconds for a SPOT instance to be started, and then fail (but allow retries)" do
    spot_instance_requests = {
    :spot_instance_request_set => [ { :spot_instance_request_id=>"sir-12345c", :other_params_here => "which aren't used" } ], 
    :request_id => "request-id-12345"
    }
    
    expect(aws_client).to receive(:describe_spot_instance_requests) \
    .exactly(10).times
    .with({:spot_instance_request_ids=>["sir-12345c"]}) \
    .and_return({ :spot_instance_request_set => [{ \
            :state => "open" \
            }] \
          })

    # When erroring, should cancel any pending spot requests
    expect(aws_client).to receive(:cancel_spot_instance_requests)

    start_waiting = Time.now

    expect {
    spot_manager.wait_for_spot_instance_request_to_be_active(spot_instance_requests)
    }.to raise_error(Bosh::Clouds::VMCreationFailed){ |error|
    expect(error.ok_to_retry).to eq true
    }

    duration = Time.now - start_waiting

    # Exact duration will vary, but anything around 0.1s is correct
    expect(duration).to be > 0.08
    expect(duration).to be < 0.12
  end

  it "should retry checking spot instance request state when AWS::EC2::Errors::InvalidSpotInstanceRequestID::NotFound raised" do

    #Simulate first recieving an error when asking for spot request state
    expect(aws_client).to receive(:describe_spot_instance_requests) \
    .with({:spot_instance_request_ids=>["sir-12345c"]}) \
    .and_raise(AWS::EC2::Errors::InvalidSpotInstanceRequestID::NotFound)
    expect(aws_client).to receive(:describe_spot_instance_requests) \
    .with({:spot_instance_request_ids=>["sir-12345c"]}) \
    .and_return({ :spot_instance_request_set => [ {:state => "active", :instance_id=>"i-12345678"} ] })

    #Shouldn't cancel spot request when things succeed
    expect(aws_client).to_not receive(:cancel_spot_instance_requests)

    expect {
      spot_manager.wait_for_spot_instance_request_to_be_active(spot_instance_requests)
    }.to_not raise_error
  end

  it "should fail VM creation (no retries) when spot bid price is below market price" do

    expect(aws_client).to receive(:describe_spot_instance_requests) \
    .with({:spot_instance_request_ids=>["sir-12345c"]}) \
    .and_return({ :spot_instance_request_set => [{ \
            :instance_id=>"i-12345678", \
            :state => "open", :status => { :code => "price-too-low" } \
            }] \
          })

    # When erroring, should cancel any pending spot requests
    expect(aws_client).to receive(:cancel_spot_instance_requests)

    expect {
      spot_manager.wait_for_spot_instance_request_to_be_active(spot_instance_requests)
    }.to raise_error(Bosh::Clouds::VMCreationFailed) { |error|
      expect(error.ok_to_retry).to eq false
    }
  end

  it "should fail VM creation (no retries) when spot request status == failed" do
   
    expect(aws_client).to receive(:describe_spot_instance_requests) \
    .with({:spot_instance_request_ids=>["sir-12345c"]}) \
    .and_return({ :spot_instance_request_set => [{ \
            :instance_id=>"i-12345678", \
            :state => "failed" \
            }] \
          })

    # When erroring, should cancel any pending spot requests
    expect(aws_client).to receive(:cancel_spot_instance_requests)
    
    expect {
      spot_manager.wait_for_spot_instance_request_to_be_active(spot_instance_requests)
    }.to raise_error(Bosh::Clouds::VMCreationFailed){ |error|
      expect(error.ok_to_retry).to eq false
    }
  end

end
