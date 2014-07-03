## Synopsis

BOSH Monitor is a component that listens to and responds to events (Heartbeats & Alerts) on the message bus (NATS). 

The Monitor also includes a few primary components:
- The Agent Monitor maintains a record of known agents (by heartbeat event subscription)
- The Director Monitor maintains a record of known agents (by director HTTP polling).
- The Agent Analyzer that analyzes agent state periodically and generates Alerts.
- The HTTP Server that responds to the /varz endpoint

The Monitor also supports generic event processing plugins that respond to Heartbeats & Alerts.

## Heartbeat Events

The Agent on each VM sends periodic heartbeats to the BOSH Monitor via the message bus (NATS).

The message syntax is as follows:

| *Subject* | *Payload* |
|-----------|-----------|
| hm.agent.heartbeat.\<agent_id\> | none |

## Alert Events

A BOSH Alert is a specific type of event sent by BOSH components via the message bus. 

Alerts includes the following data:

- Id
- Severity
- Source (usually deployment/job/index tuple)
- Timestamp
- Description
- Long description (optional)
- Tags (optional)

## Event Handling Plugins

Alerts are processed by a number of plugins that register to receive incoming alerts.

Among the included plugins are:
- Event Logger - Logs all events
- Resurrector - Restarts VMs that have stopped heartbeating
- PagerDuty - Sends various events to PagerDuty.com using their API
- DataDog - Sends various events to DataDog.com using their API
- AWS CloudWatch - Sends various events to Amazon's CloudWatch using their API
- Emailer - Sends configurable Emails on events reciept

Plugins should conform to the following interface:

| *Method* | *Arguments* | *Description* |
|----------|-------------|---------------|
| *validate_options* | | Validates the plugin configuration options |
| *run* | | Initializes the plugin process |
| *process* | event | Processes an event (Bosh::Monitor::Events::Heartbeat or Bosh::Monitor::Events::Alert) |

The event processor handles deduping duplicate events.

Plugins are notified in the order that they were registered (based on configuration order).

## Agent Monitor - Heartbeat Event Processing

The Agent Monitor listens for heartbeat events on the message bus and handles them in the following way:

- If the Agent is known to the Monitor then the last heartbeat timestamp gets updated. 
- If the Agent is unknown to the Monitor then it is recorded with a flag that marks it as a "rogue agent". 

No analysis is performed when a heatbeat is received. The Agent Analyzer process and Director Monitor polling are asynchronous to heartbeat event processing by the Agent Monitor.

## Director Monitor - Agent Discovery

The Director Monitor polls the Director periodically via HTTP to get the list of managed VMs.

The message syntax is as follows:

| *Method* | *Endpoint* | *Response* |
|----------|------------|------------|
| /deployments/\<deployment_name\>/vms | GET | JSON including agent ids, job names and indices for all managed VMs |

- If a new agent is discovered via polling then it is recorded by the Monitor as part of the managed deployment. 
- If a "rogue agent" is discovered via polling then its "rogue agent" flag is cleared.

The Director Monitor does not actively poll the agents themselves, just the Director. The Director Monitor simply remembers the state of the world as reported by polling and event processing so that the difference can be analyzed.

## Agent Analyzer

The Agent Analyzer is a periodic process that generates "Agent Missing" alerts. 

If an agent's heartbeat timestamp is not updated within the configured time period, the Agent Analyzer process will generate an "Agent Missing" alert.

Both known VM agents and rogue agents may send "Agent Missing" alerts, but they have different configurable time periods.

## Alerts from BOSH Agent

The Monitor subscribes to Agent alerts of the following format:

| *Subject* | *Payload* |
|-----------|-----------|
| hm.agent.alert.\<agent_id\> | JSON containing the following keys: id, service, event, action, description, timestamp, tags |

BOSH Agent is responsible for mapping any underlying supervisor alert format to the expected JSON payload and sending it to BOSH Monitor.

The Monitor is responsible for interpreting the JSON payload and mapping it to a sequence of Monitor & Plugin actions, possibly generating new alerts that bypass the message bus. Malformed payloads are ignored.

Job name and index are not part of alerts from the Agent, those are looked up in the Director. If heartbeat came from a rogue agent and we have no job name and/or index then we note that fact in the alert description but don't try to be too worried about that (service name and agent id should be enough). We might consider including agent IP address as a part of heartbeat so we can track down rogue agents.
