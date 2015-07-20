require 'spec_helper'

describe Bosh::AwsCloud::SpotManager do
  let(:spot_manager) { described_class.new(region) }
  let(:region) { mock_ec2 }
  before { allow(region).to receive(:security_groups).and_return(security_groups) }
  let(:security_groups) { [ double(:group, name: 'fake-group-1', security_group_id: 'fake-security-group-id') ] }

  before { allow(region).to receive(:client).and_return(aws_client) }
  let(:aws_client) { double(AWS::EC2::Client) }
  before do
    allow(aws_client).to receive(:request_spot_instances).and_return(spot_instance_requests)
    allow(aws_client).to receive(:describe_spot_instance_requests).and_return({
      spot_instance_request_set: [{
        instance_id: 'i-12345678',
        state: 'active'
      }]
    })
  end

  let(:spot_bid_price) { 0.24 }
  let(:spot_instance_requests) do
    {
      spot_instance_request_set: [
        { spot_instance_request_id: 'sir-12345c' }
      ],
      request_id: 'request-id-12345'
    }
  end

  let(:instance_params) do
    {
      image_id: 'fake-image-id',
      key_name: 'fake-key-name',
      user_data: 'fake-user-data',
      instance_type: 'fake-instance-type',
      availability_zone: 'fake-availability-zone',
      security_groups: instance_security_groups,
      private_ip_address: 'fake-private-ip-address',
      subnet: double(:subnet, subnet_id: 'fake-subnet-id')
    }
  end

  let(:instance_security_groups) { ['fake-group-1', 'fake-group-2'] }

  before { allow(region).to receive(:instances).and_return( {'i-12345678' => instance } ) }
  let(:instance) { double(AWS::EC2::Instance, id: 'i-12345678') }

  # Override total_spot_instance_request_wait_time to be "unit test" speed
  before { stub_const('Bosh::AwsCloud::SpotManager::TOTAL_WAIT_TIME_IN_SECONDS', 0.1) }

  it 'request sends AWS request for spot instance' do
    expect(aws_client).to receive(:request_spot_instances).with({
      spot_price: '0.24',
      instance_count: 1,
      launch_specification: {
        image_id: 'fake-image-id',
        key_name: 'fake-key-name',
        instance_type: 'fake-instance-type',
        user_data: %Q{ZmFrZS11c2VyLWRhdGE=\n},
        placement: {
          availability_zone: 'fake-availability-zone'
        },
        network_interfaces: [
          {
            subnet_id: 'fake-subnet-id',
            groups: ['fake-security-group-id'],
            device_index: 0,
            private_ip_address: 'fake-private-ip-address'
          }
        ]
      }
    }).and_return(spot_instance_requests)

    spot_manager.create(instance_params, spot_bid_price)
  end

  context 'when instance does not have security groups' do
    let(:instance_security_groups) { nil }

    it 'request sends AWS request for spot instance' do
      expect(aws_client).to receive(:request_spot_instances) do |request_params|
        expect(request_params[:launch_specification][:network_interfaces][0]).to_not include(:groups)
      end.and_return(spot_instance_requests)

      spot_manager.create(instance_params, spot_bid_price)
    end
  end

  it 'should wait total_spot_instance_request_wait_time() seconds for a SPOT instance to be started, and then fail (but allow retries)' do
    spot_instance_requests = {
      spot_instance_request_set: [
        { spot_instance_request_id: 'sir-12345c' }
      ],
      request_id: 'request-id-12345'
    }

    expect(aws_client).to receive(:describe_spot_instance_requests).
      exactly(10).times.with({ spot_instance_request_ids: ['sir-12345c'] }).
      and_return({ spot_instance_request_set: [{ state: 'open' }] })

    # When erroring, should cancel any pending spot requests
    expect(aws_client).to receive(:cancel_spot_instance_requests)

    expect(Bosh::Common).to receive(:retryable).
      with(sleep: 0.01, tries: 10, on: [AWS::EC2::Errors::InvalidSpotInstanceRequestID::NotFound]).
      and_call_original

    expect {
      spot_manager.create(instance_params, spot_bid_price)
    }.to raise_error(Bosh::Clouds::VMCreationFailed){ |error|
      expect(error.ok_to_retry).to eq true
    }
  end

  it 'should retry checking spot instance request state when AWS::EC2::Errors::InvalidSpotInstanceRequestID::NotFound raised' do
    #Simulate first recieving an error when asking for spot request state
    expect(aws_client).to receive(:describe_spot_instance_requests).
      with({ spot_instance_request_ids: ['sir-12345c'] }).
      and_raise(AWS::EC2::Errors::InvalidSpotInstanceRequestID::NotFound)
    expect(aws_client).to receive(:describe_spot_instance_requests).
      with({ spot_instance_request_ids: ['sir-12345c'] }).
      and_return({ spot_instance_request_set: [{ state: 'active', instance_id: 'i-12345678' }] })

    #Shouldn't cancel spot request when things succeed
    expect(aws_client).to_not receive(:cancel_spot_instance_requests)

    expect {
      spot_manager.create(instance_params, spot_bid_price)
    }.to_not raise_error
  end

  it 'should fail VM creation (no retries) when spot bid price is below market price' do
    expect(aws_client).to receive(:describe_spot_instance_requests).
      with({ spot_instance_request_ids: ['sir-12345c'] }).
      and_return(
      {
        spot_instance_request_set: [{
          instance_id: 'i-12345678',
          state: 'open',
          status: { code: 'price-too-low' }
        }]
      }
    )

    # When erroring, should cancel any pending spot requests
    expect(aws_client).to receive(:cancel_spot_instance_requests)

    expect {
      spot_manager.create(instance_params, spot_bid_price)
    }.to raise_error(Bosh::Clouds::VMCreationFailed) { |error|
      expect(error.ok_to_retry).to eq false
    }
  end

  it 'should fail VM creation (no retries) when spot request status == failed' do
    expect(aws_client).to receive(:describe_spot_instance_requests).
      with({ spot_instance_request_ids: ['sir-12345c'] }).
      and_return({
      spot_instance_request_set: [{
        instance_id: 'i-12345678',
        state: 'failed'
      }]
    })

    # When erroring, should cancel any pending spot requests
    expect(aws_client).to receive(:cancel_spot_instance_requests)

    expect {
      spot_manager.create(instance_params, spot_bid_price)
    }.to raise_error(Bosh::Clouds::VMCreationFailed) { |error|
      expect(error.ok_to_retry).to eq false
    }
  end

  it 'should fail VM creation when there is a CPI error' do
    aws_error = AWS::EC2::Errors::InvalidParameterValue.new(%q{price "0.3" exceeds your maximum Spot price limit of "0.24"})
    allow(aws_client).to receive(:request_spot_instances).and_raise(aws_error)
    expect {
      spot_manager.create(instance_params, spot_bid_price)
    }.to raise_error(Bosh::Clouds::VMCreationFailed) { |error|
      expect(error.ok_to_retry).to eq false
      expect(error.message).to include(aws_error.inspect)
    }
  end

  context 'when ephemeral disk is configured' do
    let(:instance_params) do
      {
        image_id: 'fake-image-id',
        key_name: 'fake-key-name',
        user_data: 'fake-user-data',
        instance_type: 'fake-instance-type',
        availability_zone: 'fake-availability-zone',
        security_groups: instance_security_groups,
        private_ip_address: 'fake-private-ip-address',
        subnet: double(:subnet, subnet_id: 'fake-subnet-id'),
        block_device_mappings: [
          {
            device_name: '/dev/sdb',
            ebs: {
              volume_size: 16,
              volume_type: 16,
              delete_on_termination: true,
            },
          },
        ],
      }
    end

    it 'request sends AWS request for spot instance' do
      expect(aws_client).to receive(:request_spot_instances).with({
        spot_price: '0.24',
        instance_count: 1,
        launch_specification: {
          image_id: 'fake-image-id',
          key_name: 'fake-key-name',
          instance_type: 'fake-instance-type',
          user_data: %Q{ZmFrZS11c2VyLWRhdGE=\n},
          placement: {
            availability_zone: 'fake-availability-zone'
          },
          network_interfaces: [
            {
              subnet_id: 'fake-subnet-id',
              groups: ['fake-security-group-id'],
              device_index: 0,
              private_ip_address: 'fake-private-ip-address'
            }
          ],
          block_device_mappings: [
            {
              device_name: '/dev/sdb',
              ebs: {
                volume_size: 16,
                volume_type: 16,
                delete_on_termination: true,
              },
            },
          ],
        }
      }).and_return(spot_instance_requests)

      spot_manager.create(instance_params, spot_bid_price)
    end
  end
end
