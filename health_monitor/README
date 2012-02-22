h4. Synopsis

BOSH Health Monitor (BHM) is a component that monitors health of one or multiple BOSH deployments. It processes heartbeats and alerts from BOSH agents and notifies interested parties if something goes wrong.

h4. Heartbeats

Agent sends periodic heartbeats to HM. Heartbeats are sent via message bus and have the following format:

| *Subject* | hm.agent.heartbeat.<agent_id> |
| *Payload* | none |

h6. Heartbeat processing

# If the agent is known to HM the last heartbeat timestamp gets updated. No analysis is attempted at this point, analyze agents routine is asynchronous to heartbeat processing.
# If the agent is unknown it gets registered with HM with a warning flag set (we call them rogue agents). Next director poll will possibly include this agent to a list of managed agents and clear the flag. We might generate the alert if the flag hasn't been cleared for some (configurable) time.

h4. Agents discovery

HM polls director periodically to get the list of managed VMs:

| *Endpoint* | GET /deployments/<deployment_name>/vms |
| *Response* | JSON including agent ids, job names and indices for all managed VMs |

When new agent is discovered it gets registered and added to a managed deployment. No active operations are performed to reach the agent and query it, we only rely on heartbeats and agent alerts.

h4. Agents analysis

This is a periodic operation that goes through all known agents. First it tries to go through all managed deployments, then analyzes rogue agents as well. The following procedure is used:

# If agent missed more than N heartbeats the "Agent Missing" alert is generated.

h4. Alerts

Alert is a concept used by HM to flag and deliver information about important events. It includes the following data:

# Id
# Severity
# Source (usually deployment/job/index tuple)
# Timestamp
# Description
# Long description (optional)
# Tags (optional)

h6. Alert Processor

Alert Processor is a module that registers incoming alerts and routes them to interested parties via appropriate delivery agent. It should conform to the following interface:

| *Method*         | *Arguments* | *Description* |
| *register_alert* | alert (object responding to :id, :severity, :timestamp, :description, :long_description, :source and :tags)  | Registers an alert and invokes a delivery agent. Delivery agent might or might not deliver alert immediately depending on the implementation, so Alert Processor shouldn't make any assumptions about delivery (i.e. agent might queue up several alerts and send them asynchronously. |
| *add_delivery_agent* | delivery_agent, options | Adds a delivery agent to a processor |

Alert id can be an arbitrary string however Alert Processor might use it to keep track of registered alerts and don't process the same alert twice. This way other HM modules can just blindly register any incoming alerts and leave the dedup step to the alert processor).

Alerts are only persisted in HM memory (at least in the initial version) so losing HM leads to losing any undelivered alerts that might have been queued by a delivery agent or alert processor).

If alert processor has more than one delivery agents associated with it then it notifies all of them in order (i.e. we want to notify both Zabbix and Pager Duty).

h6. Delivery Agent

Delivery Agent is a module that takes care of an alert delivery mechanism (such as an email, Pager Duty alert, writing to a journal or even silently discarding the alert). It should conform to the following interface:

| *Method* | *Arguments* | *Description* |
| *deliver* | alert | Delivers alert or queues it for delivery. |

The initial implementation will have email and Pager Duty delivery agents.

Alert Processor is not pluggable, it's just one of HM classes. Delivery agents are pluggable but generally not changed in a runtime but initialized using an HM configuration file on HM startup.

h4. Alerts from agent

HM subscribes to agent alerts on a message bus:

| *Subject* | hm.agent.alert.<agent_id> |
| *Payload* | JSON containing the following keys: id, service, event, action, description, timestamp, tags |

BOSH Agent is responsible for mapping any underlying supervisor alert format to the expected JSON payload and send it to HM.

HM is responsible for interpreting JSON payload and mapping it to a sequence of HM actions and possibly creating an HM alert compatible with Alert Processor module. HM never dedups incoming alerts outside of Alert Processor (this adds some overhead to an incoming alert parser but shouldn't be too bad). Malformed payloads are ignored.

Job name and index are not featured in agent incoming alert, those are looked up in director. If heartbeat came from a rogue agent and we have no job name and/or index then we note that fact in alert description but don't try to be too worried about that (service name and agent id should be enough). We might consider including agent IP address as a part of heartbeat so we can track down rogue agents.
