require 'spec_helper'

describe Bhm::Plugins::Email do
  before do
    Bhm.logger = logger

    @smtp_options = {
      'from' => 'hm@example.com',
      'host' => 'smtp.example.com',
      'port' => 587,
      'user' => 'usr',
      'password' => 'pwd',
      'auth' => 'plain',
      'domain' => 'example.com',
    }

    @options = {
      'recipients' => ['dude@vmware.com', 'dude2@vmware.com'],
      'smtp' => @smtp_options,
      'interval' => 0.1,
    }

    @plugin = Bhm::Plugins::Email.new(@options)
  end

  it 'validates options' do
    valid_options = {
      'recipients' => ['olegs@vmware.com'],
      'smtp' => {
        'from' => 'hm@example.com',
        'host' => 'smtp.example.com',
        'port' => 587,
        'user' => 'usr',
        'password' => 'pwd',
        'auth' => 'plain',
        'domain' => 'example.com',
      },
    }

    invalid_options = {
      'a' => 'b',
      'c' => 'd',
    }

    expect(Bhm::Plugins::Email.new(valid_options).validate_options).to eq(true)
    expect(Bhm::Plugins::Email.new(invalid_options).validate_options).to eq(false)
  end

  it 'does not start if event loop is not running' do
    expect(@plugin.run).to eq(false)
  end

  it 'has a list of recipients and smtp options' do
    expect(@plugin.recipients).to eq(['dude@vmware.com', 'dude2@vmware.com'])
    expect(@plugin.smtp_options).to eq(@smtp_options)
  end

  it 'queues up messages for delivery' do
    expect(@plugin).to_not receive(:send_email_async)

    10.times do |_i|
      @plugin.process(Bhm::Events::Base.create!(:alert, alert_payload))
      @plugin.process(Bhm::Events::Base.create!(:heartbeat, heartbeat_payload))
    end

    expect(@plugin.queue_size(:alert)).to eq(10)
    expect(@plugin.queue_size(:heartbeat)).to eq(10)
  end

  it 'processes queues when requested' do
    alerts = []

    3.times do
      alert = Bhm::Events::Base.create!(:alert, alert_payload)
      alerts << alert
      @plugin.process(alert)
    end

    heartbeats = [Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)]
    @plugin.process(heartbeats[0])

    alert_email_body = alerts.map(&:to_plain_text).join("\n") + "\n"
    heartbeat_email_body = heartbeats.map(&:to_plain_text).join("\n") + "\n"

    expect(@plugin).to receive(:send_email_async)
      .with('3 alerts from BOSH Health Monitor', alert_email_body).once.and_return(true)
    expect(@plugin).to receive(:send_email_async)
      .with('1 heartbeat from BOSH Health Monitor', heartbeat_email_body).once.and_return(true)
    @plugin.process_queues
  end

  it 'processes queue asynchronously when running' do
    allow(@plugin).to receive(:send_email_async)

    20.times do |_i|
      @plugin.process(Bhm::Events::Base.create!(:heartbeat, heartbeat_payload))
      @plugin.process(Bhm::Events::Base.create!(:alert, alert_payload))
    end

    expect(@plugin.queue_size(:alert)).to eq(20)
    expect(@plugin.queue_size(:heartbeat)).to eq(20)

    Sync do |task|
      task.with_timeout(5) do
        @plugin.run

        loop do
          sleep 0.5
          break if @plugin.queue_size(:alert).zero? && @plugin.queue_size(:heartbeat).zero?
        end
      end
    ensure
      task.stop
    end

    expect(@plugin.queue_size(:alert)).to eq(0)
    expect(@plugin.queue_size(:heartbeat)).to eq(0)
  end

  it 'writes datetime headers compliant with rfc5322' do
    headers = @plugin.create_headers('Some subject', Time.now)
    expect(headers).to be_truthy
    date_value = headers['Date']
    expect(date_value).to be_truthy
    expect(/[[:alpha:]]{3}, \d{1,2} [[:alpha:]]{3} \d{4} \d{2}:\d{2}:\d{2} [\+,\-].+/).to match(date_value)
  end
end
