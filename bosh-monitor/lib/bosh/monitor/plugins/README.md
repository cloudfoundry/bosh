#Using Bosh Monitor Plugins

##AWS CloudWatch
Sends various events to Amazon's CloudWatch using their

##DataDog
Sends various events to DataDog.com using their API

| option           | description            |
|------------------|------------------------|
| api_key          | Your api Key           |
| application_key  | Your Application Key   |

##Consul Plugin
The Consul plugin works by forwarding nats heartbeat events and alerts to a consul server or agent. The nats messages can be forwarded as ttl checks and events.

| option             | description                         |
|--------------------|-------------------------------------|
|  host              | The address of the cluster or agent |
|  namespace         | A namespace to separate multiple instances of the same release
|  events_api        | The events api endpoint defaults to /v1/event/fire/
|  ttl_api           | The Check update and registration endpoint defaults to /v1/agent/check/
|  port              | Defaults to 8500
|  protocal          | Defaults to HTTP
|  params            | Can be used to pass access token "token=MYACCESSTOKEN"
|  ttl               | TTL Checks will be used if a ttl period is set here. Example "120s"
|  events            | If set to true heartbeats will be forwarded as events
|  ttl_note          | A note that will be passed back to consul with a ttl check

## Event Logger
 Logs all events

## PagerDuty
Sends various events to PagerDuty.com using their API

## Resurrector
Restarts VMs that have stopped heartbeating
