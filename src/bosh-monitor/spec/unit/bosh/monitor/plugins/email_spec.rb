require 'spec_helper'

describe Bosh::Monitor::Plugins::Email do
  before do
    Bosh::Monitor.logger = logger

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
      'recipients' => ['recipient@example.com', 'recipient2@example.com'],
      'smtp' => @smtp_options,
      'interval' => 0.1,
    }

    @plugin = Bosh::Monitor::Plugins::Email.new(@options)
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

    expect(Bosh::Monitor::Plugins::Email.new(valid_options).validate_options).to eq(true)
    expect(Bosh::Monitor::Plugins::Email.new(invalid_options).validate_options).to eq(false)
  end

  it 'does not start if event loop is not running' do
    expect(@plugin.run).to eq(false)
  end

  it 'has a list of recipients and smtp options' do
    expect(@plugin.recipients).to eq(['recipient@example.com', 'recipient2@example.com'])
    expect(@plugin.smtp_options).to eq(@smtp_options)
  end

  it 'queues up messages for delivery' do
    expect(@plugin).to_not receive(:send_email_async)

    10.times do |_i|
      @plugin.process(Bosh::Monitor::Events::Base.create!(:alert, alert_payload))
      @plugin.process(Bosh::Monitor::Events::Base.create!(:heartbeat, heartbeat_payload))
    end

    expect(@plugin.queue_size(:alert)).to eq(10)
    expect(@plugin.queue_size(:heartbeat)).to eq(10)
  end

  it 'processes queues when requested' do
    alerts = []

    3.times do
      alert = Bosh::Monitor::Events::Base.create!(:alert, alert_payload)
      alerts << alert
      @plugin.process(alert)
    end

    heartbeats = [Bosh::Monitor::Events::Base.create!(:heartbeat, heartbeat_payload)]
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
      @plugin.process(Bosh::Monitor::Events::Base.create!(:heartbeat, heartbeat_payload))
      @plugin.process(Bosh::Monitor::Events::Base.create!(:alert, alert_payload))
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

  it 'correctly formats the email message' do
    date = Time.utc(2024, 1, 2, 3, 4, 5)
    headers = @plugin.create_headers('Some subject', date)
    message = @plugin.formatted_message(headers, "This is the body text")


    expected_message = "From: hm@example.com\r\nTo: recipient@example.com, recipient2@example.com\r\nSubject: Some subject\r\nDate: Tue, 2 Jan 2024 03:04:05 +0000\r\nContent-Type: text/plain; charset=\"iso-8859-1\"\r\n\r\nThis is the body text"

    expect(message).to eq(expected_message)
  end

  it 'writes datetime headers compliant with rfc5322' do
    headers = @plugin.create_headers('Some subject', Time.now)
    expect(headers).to be_truthy
    date_value = headers['Date']
    expect(date_value).to be_truthy
    expect(/[[:alpha:]]{3}, \d{1,2} [[:alpha:]]{3} \d{4} \d{2}:\d{2}:\d{2} [\+,\-].+/).to match(date_value)
  end

  context 'Net::SMTP canary' do
    # Currently the Health Monitor email plugin does not support direct TLS connections, only
    # STARTTLS commands during an existing SMTP session. We are relying on TLS being false by
    # default in the Net::SMTP class.
    it 'defaults tls to false' do
      smtp = Net::SMTP.new('example.com', 25)
      expect(smtp.tls?).to eq(false)
    end
  end
end
