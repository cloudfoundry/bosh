#Using Bosh Monitor Plugins

##AWS CloudWatch
Sends various events to Amazon's CloudWatch using their

##DataDog
Sends various events to DataDog.com using their API

| option           | description            |
|------------------|------------------------|
| api_key          | Your api Key           |
| application_key  | Your Application Key   |

##Consul Event Forwarder Plugin
The Consul plugin works by forwarding nats heartbeat events and alerts to a consul server or agent. The nats messages can be forwarded as ttl checks and events. Heartbeat messages will be forwarded as TTL checks, each time a heartbeat occurs it will update the ttl check with it's status. When an alert occurs it will be forwareded to Consul as an Event. The current best use case seems to be to forward to a consul agent (possibly on your inception server)

| option                | description                         |
|-----------------------|-------------------------------------|
|  host                 | The address of the cluster or agent |
|  namespace            | A namespace to separate multiple instances of the same release
|  events_api           | The events api endpoint defaults to /v1/event/fire/
|  ttl_api              | The Check update and registration endpoint defaults to /v1/agent/check/
|  port                 | Defaults to 8500
|  protocal             | Defaults to HTTP
|  params               | Can be used to pass access token "token=MYACCESSTOKEN"
|  ttl                  | TTL Checks will be used if a ttl period is set here. Example "120s"
|  events               | If set to true heartbeats will be forwarded as events
|  ttl_note             | A note that will be passed back to consul with a ttl check
|  heartbeats_as_alerts | * If set to true all heartbeats will also be forwarded as event, this gives you 'real time' vitals data to correlate with

####* When heartbeats are sent as alerts the format has been made more concise to come in under the event payload bytesize limits that consul enforces
```ruby
{
  :agent  => agent_id,
  :name   => "job_name / index",
  :state  => job_state,
  :data   => {
      :cpu => [sys, user, wait]
      :dsk => {
        :eph => [inode_percent, percent],
        :sys =>[inode_percent, percent]
      }
      :ld  => load,
      :mem => [kb, percent],
      :swp => [kb, percent]
  }
}
```

## Event Logger
 Logs all events

## PagerDuty
Sends various events to PagerDuty.com using their API

## Resurrector
Restarts VMs that have stopped heartbeating
