class PagingDatadogClient
  def initialize(datadog_recipient, datadog_client)
    @datadog_recipient = datadog_recipient
    @datadog_client = datadog_client
  end

  def emit_points(metric, points, options={})
    @datadog_client.emit_points(metric, points, options)
  end

  def emit_event(event)
    event_hash = event.to_hash
    new_message = "#{event.msg_text} @#{@datadog_recipient}"
    new_event = Dogapi::Event.new(new_message, event_hash)

    @datadog_client.emit_event(new_event)
  end
end