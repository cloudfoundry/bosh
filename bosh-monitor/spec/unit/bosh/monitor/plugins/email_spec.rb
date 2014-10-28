require 'spec_helper'

describe Bhm::Plugins::Email do

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)

    @smtp_options = {
      'from' => 'hm@example.com',
      'host' => 'smtp.example.com',
      'port' => 587,
      'user' => 'usr',
      'password' => 'pwd',
      'auth' => 'plain',
      'domain' => 'example.com'
    }

    @options = {
      'recipients' => [ 'dude@vmware.com', 'dude2@vmware.com'],
      'smtp' => @smtp_options,
      'interval' => 0.1
    }

    @plugin = Bhm::Plugins::Email.new(@options)
  end

  it 'validates options' do
    valid_options = {
      'recipients' => [ 'olegs@vmware.com' ],
      'smtp' => {
        'from'     => 'hm@example.com',
        'host'     => 'smtp.example.com',
        'port'     => 587,
        'user'     => 'usr',
        'password' => 'pwd',
        'auth'     => 'plain',
        'domain'   => 'example.com'
      }
    }

    invalid_options = {
      'a' => 'b',
      'c' => 'd'
    }

    expect(Bhm::Plugins::Email.new(valid_options).validate_options).to eq(true)
    expect(Bhm::Plugins::Email.new(invalid_options).validate_options).to eq(false)
  end

  it 'does not start if event loop is not running' do
    EM.stop if EM.reactor_running?
    expect(@plugin.run).to eq(false)
  end

  it 'has a list of recipients and smtp options' do
    expect(@plugin.recipients).to eq([ 'dude@vmware.com', 'dude2@vmware.com' ])
    expect(@plugin.smtp_options).to eq(@smtp_options)
  end

  it 'queues up messages for delivery' do
    expect(@plugin).to_not receive(:send_email_async)

    10.times do |i|
      @plugin.process(Bhm::Events::Base.create!(:alert, alert_payload))
      @plugin.process(Bhm::Events::Base.create!(:heartbeat, heartbeat_payload))
    end

    expect(@plugin.queue_size(:alert)).to eq(10)
    expect(@plugin.queue_size(:heartbeat)).to eq(10)
  end

  it 'processes queues when requested' do
    alerts = [ ]

    3.times do
      alert = Bhm::Events::Base.create!(:alert, alert_payload)
      alerts << alert
      @plugin.process(alert)
    end

    heartbeats = [ Bhm::Events::Base.create!(:heartbeat, heartbeat_payload) ]
    @plugin.process(heartbeats[0])

    alert_email_body = alerts.map{ |alert| alert.to_plain_text }.join("\n") + "\n"
    heartbeat_email_body = heartbeats.map{ |hb| hb.to_plain_text }.join("\n") + "\n"

    expect(@plugin).to receive(:send_email_async).with('3 alerts from BOSH Health Monitor', alert_email_body).once.and_return(true)
    expect(@plugin).to receive(:send_email_async).with('1 heartbeat from BOSH Health Monitor', heartbeat_email_body).once.and_return(true)
    @plugin.process_queues
  end

  it 'processes queue asynchronously when running' do
    allow(@plugin).to receive(:send_email_async)

    20.times do |i|
      @plugin.process(Bhm::Events::Base.create!(:heartbeat, heartbeat_payload))
      @plugin.process(Bhm::Events::Base.create!(:alert, alert_payload))
    end

    expect(@plugin.queue_size(:alert)).to eq(20)
    expect(@plugin.queue_size(:heartbeat)).to eq(20)

    EM.run do
      EM.add_timer(30) { EM.stop }
      EM.add_periodic_timer(0.1) do
        if @plugin.queue_size(:alert) == 0 && @plugin.queue_size(:heartbeat) == 0
          EM.stop
        end
      end
      @plugin.run
    end

    expect(@plugin.queue_size(:alert)).to eq(0)
    expect(@plugin.queue_size(:heartbeat)).to eq(0)
  end

end
