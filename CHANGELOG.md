# Release 0.24.7

* Bug fix: bbolt deadlock that could happen if posture cache evaluation coincided with a bbolt mmap operation
    * regression introduced in v0.22.1
* Bug fix: metrics event filtering 
    * regression introduced in 0.24.5 with the metrics name change

# Release 0.24.6

* Update bbolt library to v1.3.6 

# Release 0.24.5

* Enhancement: Durable Eventual Events
* Enhancement: API Session/Service Policy Enforcer Metrics
* Enhancement: Support Controller Address Changes
* Enhancement: Control Channel Metrics Split
* Enhancement: Metrics Output Size Reduction
* Enhancement: Channel Library Updates

## Durable Eventual Events

The controller now supports internal events to delay the processing cost of operations that do not need to resolve
immediately, but must resolve at some point. Events in the controller may pile up at increased load time and that load
level can be seen in a new gauge metric `eventual.events`.

- `eventual.events` - The count of outstanding eventual events

## API Session/Service Policy Enforcer Metrics

New metrics have been added to track internal processes of the controller that enforces API Sessions and Service
Policies.

- `api.session.enforcer.run` - a timer metric of run time of the API Session enforcer
- `api.session.enforcer.delete` - a meter metric of the number of API Sessions deleted
- `service.policy.enforcer.run` - a timer metric of run time of the Service Policy enforcer
- `service.policy.enforcer.event` - a timer metric of the run time for discrete enforcer events
- `service.policy.enforcer.event.deletes` - a meter of the number of signaling delete events processed
- `service.policy.enforcer.run.deletes` - a meter of the number of actual session deletes processed

## Support Controller Address Changes

The Ziti controller now supports additional address fields which can be used to signal endpoint software and routers to
update their configured controller address. The settings are useful in scenarios where moving between IP/hostnames is
desired. Use of these settings has security concerns that must be met in order to maintain connectivity and trust
between endpoint software and routers.

### Security Requirements

These are true for all REST API and control channel addresses.

1) The old IP/hostname and the new IP/hostname must be present on the certificate defined by the `cert` field before
   starting the transition
2) Adding the new IP/hostname to the SANs of an existing controller will require the generating and signing of a new
   certificate
3) The newly generated and signed certificate must still validate with the CAs provided to routers and endpoints
4) The old IP/hostname can only be removed after all in-use routers/endpoints have connected and upgraded addresses

### Process Outline

1) Generate new server certificates with additional SANs for the new IP/hostname - transitional server certificate
2) Update the controller configure to use the new transitional server certificate for the desired listeners (
   control/REST APIs)
3) Restart the controller
4) Upgrade all routers to v0.24.5 or later
5) Upgrade all SDK clients to versions that support controller address changes
6) Verify existing routers and REST API clients can still connect with the old IP/hostname
7) Define the new settings required for the REST APIs (`newAddress`) and/or control channel (`newListener`), see below
8) Restart the controller
9) Verify existing routers and REST API clients configuration files have updated
10) After all clients/routers have updated their addresses, transition the `newAddress` and `newListener` values to the
    default `address` and `listener` fields.
11) Remove the `newAddress` and `newListener` fields.
12) Restart the controller
13) Optionally generate a new server certificate without the old IP/hostname SANs and verify clients/routers can connect

Notes:

- This process may take days, weeks, or months depending on the size of the nework and how often the router/clients are
  run
- It is imperative that all clients/routers that will remain in use after the IP/hostname move connect at least once
  after `newAddress` and `newListener` values are configured and in use
- Clients/routers that do not receive the new address will need to be manually reconfigured by finding their
  configuration file and updating the controller address

### Control Channel Setting

The controller listener defined in the `ctrl` section now supports a `newListener` option which must be a supported
address format (generally in the form of `<protocol>:<host>:<port>`).

Once `newListener` is set, the controller will start to send out the new listener address to connecting routers after
the controller is restarted. All security concerns listed above must be met or routers will not be able to connect to
the controller.

```
ctrl:
  listener: tls:127.0.0.1:6262
  options:
    # (optional) settings
    # ...

    # A listener address which will be sent to connecting routers in order to change their configured controller
    # address. If defined, routers will update address configuration to immediately use the new address for future
    # connections. The value of newListener must be resolvable both via DNS and validate via certificates
    #newListener: tls:localhost:6262
```

### REST API Setting

REST APIs addresses are defined in the `web` section of the controller configuration. The `web` sections
contains `bindPoint`s that define which network interfaces the REST API server will listen on via the
`interface` field. The external address used to access that `bindPoint` is defined by the `address` field. An
additional `newAddress` field can optionally be set.

Once `newAddress` is set, the controller will start to send out the new address to all clients via the HTTP
header `ziti-ctrl-address`. The header will be present on all responses from the controller for the specific
`bindPoint`. All security concerns listed above must be met or client will not be able to connect to the controller.

```
web:
  # name - required
  # Provides a name for this listener, used for logging output. Not required to be unique, but is highly suggested.
  - name: all-apis-localhost
    # bindPoints - required
    # One or more bind points are required. A bind point specifies an interface (interface:port string) that defines
    # where on the host machine the webListener will listen and the address (host:port) that should be used to
    # publicly address the webListener(i.e. mydomain.com, localhost, 127.0.0.1). This public address may be used for
    # incoming address resolution as well as used in responses in the API.
    bindPoints:
      #interface - required
      # A host:port string on which network interface to listen on. 0.0.0.0 will listen on all interfaces
      - interface: 127.0.0.1:1280

        # address - required
        # The public address that external incoming requests will be able to resolve. Used in request processing and
        # response content that requires full host:port/path addresses.
        address: 127.0.0.1:1280

        # newAddress - optional
        # A host:port string which will be sent out as an HTTP header "ziti-new-address" if specified. If the header
        # is present, clients should update location configuration to immediately use the new address for future
        # connections. The value of newAddress must be resolvable both via DNS and validate via certificates
        newAddress: localhost:1280
```

## Control Channel Latency Metrics Changes

The control channel metrics have been broken into two separate metrics. Previously the metric measured how long it took for the message to be enqueued, sent and a reply received. Now the time to write to wire has been broken out.

* `ctrl.latency` - This now measures the time from wire send to response received
* `ctrl.queue_time` - This measure the time from when the send is requested to when it actually is written to the wire

## Metrics Output Size Reduction

If using the JSON metrics events output, the output has changed.

A metrics entry which previously would have looked like:

```
{
  "metric": "ctrl.tx.bytesrate",
  "metrics": {
    "ctrl.tx.bytesrate.count": 222,
    "ctrl.tx.bytesrate.m15_rate": 0.37625904063382576,
    "ctrl.tx.bytesrate.m1_rate": 0.12238911649077193,
    "ctrl.tx.bytesrate.m5_rate": 0.13784280219782497,
    "ctrl.tx.bytesrate.mean_rate": 0.1373326200238093
  },
  "namespace": "metrics",
  "source_entity_id": "z7ZmJux8a7",
  "source_event_id": "7b77ac53-c017-409e-afcc-fd0e1878a301",
  "source_id": "ctrl_client",
  "timestamp": "2022-01-26T21:46:45.866133131Z"
}
```

will now look like:

```
{
  "metric": "ctrl.tx.bytesrate",
  "metrics": {
    "count": 222,
    "m15_rate": 0.37625904063382576,
    "m1_rate": 0.12238911649077193,
    "m5_rate": 0.13784280219782497,
    "mean_rate": 0.1373326200238093
  },
  "namespace": "metrics",
  "source_entity_id": "z7ZmJux8a7",
  "source_event_id": "7b77ac53-c017-409e-afcc-fd0e1878a301",
  "source_id": "ctrl_client",
  "timestamp": "2022-01-26T21:46:45.866133131Z",
  "version" : 2
}
```

Note that the metric keys no longer have the metric name as a prefix. Also, the emitted metric has a new `version` field which is set to 2. 

Metrics with a single key, which previously looked like:

```
{
  "metric": "xgress.acks.queue_size",
  "metrics": {
    "xgress.acks.queue_size": 0
  },
  "namespace": "metrics",
  "source_event_id": "6eb30de2-55de-49d5-828f-4268a3707512",
  "source_id": "z7ZmJux8a7",
  "timestamp": "2022-01-26T22:06:33.242933687Z",
  "version": 2
}
```

now look like:

```
{
  "metric": "xgress.acks.queue_size",
  "metrics": {
    "value": 0
  },
  "namespace": "metrics",
  "source_event_id": "6eb30de2-55de-49d5-828f-4268a3707512",
  "source_id": "z7ZmJux8a7",
  "timestamp": "2022-01-26T22:06:33.242933687Z",
  "version": 2
}
```

## Channel Library Updates

The channel library, which is used by edge communications, control channel, links and management channel, has been refactored. It now does a better job handling canceled messaged through the send process. If a message send times out before it is sent, the message will now no longer be sent when it gets to the head of the queue. Channels can now be instrumented to allow better metrics gathering, as seen above the the split out control channel latency metrics. Channel internals have also been refactored so that initialization is better defined, leading to better concurrency characteristics. 

# Release 0.24.4

## What's New

* Enhancement: Cache sessions for the router/tunneler, to minimize the creation of unnecessary sessions
* Enhancement: Add send timeouts for route messages
* Enhancement: Add write timeout configuration for control channel
* Enhancement: API Session and Session deletes are now separate and eventually consistent
* Enhancement: API Session synchronization with routers no longer blocks database transactions
* Bug fix: fix message priority sorting

## Control Channel Timeouts

The controller config file now allows setting a write timeout for control channel connections. If a control channel
write times out, because the connection is in a bad state or because a router is in a bad state, the control channel
will be closed. This will allow the router to reconnect.

```
ctrl:
  listener:             tls:127.0.0.1:6262
    options:
      # Sets the control channel write timeout. A write timeout will close the control channel, so the router will reconnect
      writeTimeout: 15s
``` 

# Release 0.24.3

## What's New

* Enhancement: API Session delete events now include the related identity id
* Enhancement: controller and router start up messages now include the component id
* Enhancement: New metric `identity.refresh` which counts how often an identity should have to refresh the service list
  because of a service, config or policy change
* Enhancement: Edge REST services will now set the content-length on response, which will prevent response from being
  chunked
* Enhancement: Edge REST API calls will now show in metrics in the format of <path>.<method>
* Bug fix: fix controller panic during circuit creation if router is unexpectedly deleted during routing

# Release 0.24.2

## What's New

* Bug fix: link verification could panic if link was established before control was finished establishing
* Bug fix: When checking edge terminator validity in the router, check terminator id as well the address
* Bug fix: xweb uses idleTimeout correctly, was previously using writeTimeout instead
* Enhancement: Improve logging around links in routers. Ensure we close both channels when closing a split link
* Enhancement: Add support for inspect in `ziti fabric`. Works the same as `ziti-fabric inspect`

# Release 0.24.1

## What's New

* Bug Fix: Very first time using ziti cli to login with `ziti edge login` would panic
* Security: When using new fabric REST API in fabric only mode, certs weren't being properly checked. Regression exists
  only in 0.24.0

# Release 0.24.0

## Breaking Changes

* ziti-fabric-gw has been removed since the fabric now has its own REST API
* ziti-fabric-test is no longer being built by default and won't be included in future release bundles.
  Use `go build --tags all ./...` to build it
* ziti-fabric has been deprecated. Most of its features are now available in the `ziti` CLI under `ziti fabric`

## What's New

* Feature: Fabric REST API
* Performance: Additional route selection work
* Bug Fix: Fix controller deadlock which can happen if a control channel is closed while controller is responding
* Bug fix: Fix panic for UDP-only tproxy intercepts

## Fabric REST API

The fabric now has a REST API in addition to the channel2 management API. To enable it, add the fabric binding to the
apis section off the xweb config, as follows:

```
    apis:
      # binding - required
      # Specifies an API to bind to this webListener. Built-in APIs are
      #   - health-checks
      - binding: fabric
```

If running without the edge, the fabric API uses client certificates for authorization, much like the existing channel2
mgmt based API does. If running with the edge, the edge provides authentication/authorization for the fabric REST APIs.

### Supported Operations

These operations are supported in the REST API. The ziti CLI has been updated to use this in the new `ziti fabric`
sub-command.

* Services: create/read/update/delete
* Routers: create/read/update/delete
* Terminators: create/read/update/delete
* Links: read/update
* Circuits: read/delete

### Unsupported Operations

Some operations from ziti-fabric aren't get supported:

* Stream metrics/traces/circuits
    * This feature may be re-implemented in terms of websockets, or may be left as-is, or may be dropped
* Inspect (get stackdumps)
    * This will be ported to `ziti fabric`
* Decode trace files
    * This may be ported to `ziti-ops`

# Release 0.23.1

## What's New

* Performance: Improve route selection cpu and memory use.
* Bug fix: Fix controller panic in routes.MapApiSessionToRestModel caused by missing return

# Release 0.23.0

## What's New

* Bug fix: Fix panic in router when router is shutdown before control channel is established
* Enhancement: Add source/target router ids on link metrics.
* Security: Fabric management channel wasn't properly validating certs against the server cert chain
* Security: Router link listeners weren't properly validating certs against the server cert chain
* Security: Link listeners now validate incoming links to ensure that the link was requested by the controller and the
  correct router dialed
* Security: Don't allow link forwarding entries to be overriden, as link ids should be unique
* Security: Validate ctrl channel clients against controller cert chain in addition to checking cert fingerprint

## Breaking Changes

The link validation required a controller side and router side component. The controller will continue to work with
earlier routers, but the routers with version >= 0.23.0 will need a controller with version >= 0.23.0.

## Link Metrics Router Ids

The link router ids will now be included as tags on the metrics.

```
{
  "metric": "link.latency",
  "metrics": {
    "link.latency.count": 322,
    "link.latency.max": 844083,
    "link.latency.mean": 236462.8671875,
    "link.latency.min": 100560,
    "link.latency.p50": 212710.5,
    "link.latency.p75": 260137.75,
    "link.latency.p95": 491181.89999999997,
    "link.latency.p99": 820171.6299999995,
    "link.latency.p999": 844083,
    "link.latency.p9999": 844083,
    "link.latency.std_dev": 118676.24663550049,
    "link.latency.variance": 14084051515.49014
  },
  "namespace": "metrics",
  "source_entity_id": "lDWL",
  "source_event_id": "52f9de3e-4293-4d4f-9dc8-5c4f40b04d12",
  "source_id": "4ecTdw8lG6",
  "tags": {
    "sourceRouterId": "CorTdA8l7",
    "targetRouterId": "4ecTdw8lG6"
  },
  "timestamp": "2021-11-10T18:04:32.087107445Z"
}
```

Note that this information is injected into the metric in the controller. If the controller doesn't know about the link,
because of a controller restart, the information can't be added.

# Release 0.22.11

## What's New

* Feature: API Session Events

## API Session Events

API Session events can now be configured by adding `edge.apiSessions` under event subscriptions. The events may be of
type `created` and `deleted`. The event type can be filtered by adding an `include:` block, similar to edge sessions.

The JSON output looks like:

```
{
  "namespace": "edge.apiSessions",
  "event_type": "created",
  "id": "ckvr2r4fs0001oigd6si4akc8",
  "timestamp": "2021-11-08T14:45:45.785561479-05:00",
  "token": "77cffde5-f68e-4ef0-bbb5-731db36145f5",
  "identity_id": "76BB.shC0",
  "ip_address": "127.0.0.1"
}
```

# Release 0.22.10

# What's New

* Bug fix: address client certificate changes altered by library changes
* Bug fix: fixes a panic on session read in some situations
* Enhancement: Certificate Authentication Extension provides the ability to extend certificate expiration dates in the
  Edge Client and Management APIs

## Certificate Authentication Extension

The Edge Client and Management APIs have had the following endpoint added:

- `POST /current-identity/authenticators/{id}/extend`

It is documented as:

```
Allows an identity to extend its certificate's expiration date by
using its current and valid client certificate to submit a CSR. This CSR may
be passed in using a new private key, thus allowing private key rotation.

After completion any new connections must be made with certificates returned from a 200 OK
response. The previous client certificate is rendered invalid for use with the controller even if it
has not expired.

This request must be made using the existing, valid, client certificate.
```

An example input is:

```
{
    "clientCertCsr": "...<csr>..."
}
```

Output responses include:

- `200 OK` w/ empty object payloads: `{}`
- `401 UNAUTHORIZED` w/ standard error messaging
- `400 BAD REQUESET` w/ standard error messaging for field errors or CSR processing errors

# Release 0.22.9

# What's New

* Build: This release adds an arm64 build and improved docker build process

# Release 0.22.8

# What's New

* Bug fix: Workaround bbolt bug where cursor next sometimes skip when current is deleted. Use skip instead of next.
  Fixes orphan session issue.
* Bug fix: If read fails on reconnecting channel, close peer before trying to reconnect
* Bug fix: Don't log every UDP datagram at info level in tunneler
* Change: Build with -trimpath to aid in plugin compatibility

# Release 0.22.7

# What's New

* Bug fix: Router automatic certificate enrollments will no longer require a restart of the router
* Enhancement: foundation Identity implementations now support reloading of tls.Config certificates for CAs
* Enhancement: foundation Identity library brought more in-line with golang idioms
* Experimental: integration with PARSEC key service
* Bug fix: Fix controller panic when router/tunnel tries to host invalid service

## PARSEC integration (experimental)

Ziti can now use keys backed by PARSEC service for identity. see https://parallaxsecond.github.io/parsec-book/index.html

example usage during enrollment (assuming `my-identity-key` exists in PARSEC service):

```
$ ziti-tunnel enroll -j my-identity.jwt --key parsec:my-identity-key
```

# Release 0.22.6

# What's New

* Enhancement: Add terminator_id and version to service events. If a service event relates to a terminator, the
  terminator_id will now be included. Service events now also have a version field, which is set to 2.
* Enhancement: Don't let identity/service/edge router role attributes start with a hashtag or at-symbol to prevent
  confusion.
* Bug fix: Timeout remaining for onWake/onUnlock will properly report as non-zero after MFA submission
* Enhancement: traceroute support
* Enhancement: add initial support for UDP links

## Traceroute

The Ziti cli and Ziti Golang SDK now support traceroute style operations. In order for this to work the SDK and routers
must be at version 0.22.6 or greater. This is currently only supported in the Golang SDK.

The SDK can perform a traceroute as follows:

```
conn, err := ctx.Dial(o.Args[0])
result, err := conn.TraceRoute(hop, time.Second*5)
```

The result structure looks like:

```
type TraceRouteResult struct {
    Hops    uint32
    Time    time.Duration
    HopType string
    HopId   string
}
```

Increasing numbers of hops can be requested until the hops returned is greater than zero, indicating that additional
hops weren't available. This functionality is available in the Ziti CLI.

```
$ ziti edge traceroute simple -c ./simple-client.json 
 1               xgress/edge    1ms 
 2     forwarder[n4yChTL3Jy]     0s 
 3     forwarder[Yv7BPW0kGR]     0s 
 4               xgress/edge    1ms 
 5                sdk/golang     0s 

plorenz@carrot:~/work/nf$ ziti edge traceroute simple -c ./simple-client.json 
 1               xgress/edge     0s 
 2     forwarder[n4yChTL3Jy]     0s 
 3     forwarder[Yv7BPW0kGR]    1ms 
 4     xgress/edge_transport     0s 
```

# Release 0.22.5

## What's New

* Update from Go 1.16 to Go 1.17

# Release 0.22.4

## What's New

* Bug fix: Ziti CLI creating a CA now has the missing `--identity-name-format` / `-f` option
* Bug fix: Edge router/tunneler wasn't getting per-service precedence/cost defined on identity
* Cleanup: The HA terminator strategy has been removed. The implementation was incomplete on its own. Use health checks
  instead of active/passive setups

# Release 0.22.3

## What's New

* Bug fix: Fix panic in listener close if the socket hadn't been initalized yet
* Bug fix: Fix panic in posture bulk create if mfa wasn't set
* Bug fix: Fix panic in circuit creation on race condition when circuits are add/removed concurrently

# Release 0.22.2

## What's New

* Bug fix: Upgrading a controller from 0.22.0 or earlier to 0.22.2 will no longer leave old sessions w/o identityId
  properties. Workaround for previous versions is to use `ziti-controller delete-sessions`
* Bug fix: If a router/tunneler loses connectivity with the controller long enough for the api session to time out, the
  router will now restablish any terminators for hosted services
* Enhancement: Add some short aliases for the CLI
    * edge-router -> er
    * service-policy -> sp
    * edge-router-policy -> erp
    * service-edge-router-policy -> serp
* Feature: Add GetServiceTerminators to Golang SDK ziti.Context
* Feature: Add GetSourceIdentifier to Golang SDK edge.ServiceConn

# Release 0.22.1

## What's New

* Bug fix: Fabric v0.16.93 fixes `xgress.GetCircuit` to provide a `ctrl not ready` error response when requests arrive
  before the router is fully online.
* Bug fix: Ziti CLI will no longer truncate paths on logins with explicit URLs
* Bug fix: Ziti CLI will now correctly check the proper lengths of sha512 hashes in hex format
* Bug fix: MFA Posture Check timeout will no longer be half their set value
* Bug fix: MFA Posture Checks w/ a timeout configured to 0 will be treated as having no timeout (-1) instead of always
  being timed out
* Bug fix: MFA Posture Checks will no longer cause an usually high frequency of session updates
* Bug fix: MFA Posture Checks during subsequent MFA submissions will no longer 401
* Bug fix: Listing sessions via `GET /sessions` will no longer report an error in certain data states
* Feature: Posture responses now report services affected with timeout/state changes
* Feature: Ziti CLI `unwrap` command for identity json files will now default the output file names
* Feature: Ziti CLI improvements
    * New interactive tutorial covering creating your first service. Run using: `ziti edge tutorial first-service`
    * You can now delete multiple entities at once, by providing multiple ids. Ex: `ziti edge delete services one two`
      or `ziti edge delete service one two` will both work.
    * You can now delete multiple entities at once, by providing a filter.
      Ex: `ziti edge delete services where 'name contains "foo"`
    * Create and delete output now has additional context.
* Feature: Terminators can now be filtered by service and router name:
  Ex: `ziti edge list terminators 'service.name = "echo"'`
* Feature: New event type `edge.entityCounts`

## Entity Count Events

The Ziti Controller can now generate events with a summary of how many of each entity type are currently in the data
store. It can be configured with an interval for how often the event will be generated. The default interval is five
minutes.

```
events:
  jsonLogger:
    subscriptions:
      - type: edge.entityCounts
        interval: 5m
```

Here is an example of the JSON output of the event:

```
{
  "namespace": "edge.entityCounts",
  "timestamp": "2021-08-19T13:39:54.056181406-04:00",
  "counts": {
    "apiSessionCertificates": 0,
    "apiSessions": 9,
    "authenticators": 4,
    "cas": 0,
    "configTypes": 5,
    "configs": 2,
    "edgeRouterPolicies": 4,
    "enrollments": 0,
    "eventLogs": 0,
    "geoRegions": 17,
    "identities": 6,
    "identityTypes": 4,
    "mfas": 0,
    "postureCheckTypes": 5,
    "postureChecks": 0,
    "routers": 2,
    "serviceEdgeRouterPolicies": 2,
    "servicePolicies": 5,
    "services": 3,
    "sessions": 0
  },
  "error": ""
}
```

# Release 0.22.0

## What's New

* Refactor: Fabric Sessions renamed to Circuits (breaking change)
* Feature: Links will now wait for a timeout for retrying
* Bug fix: Sessions created on the controller when circuit creation fails are now cleaned up
* Feature: Enhanced `ziti` CLI login functionality (has breaking changes to CLI options)
* Feature: new `ziti edge list summary` command, which shows database entity counts
* Bug fix: ziti-fabric didn't always report an error to the OS when it had an error
* Refactor: All protobuf packages have been prefixed with `ziti.` to help prevent namespace clashes. Should not be a
  breaking change.
* Feature: Selective debug logging by identity for path selection and circuit establishment
    * `ziti edge trace identity <identity id>` will turn on debug logging for selecting paths and establishing circuits
    * Addition context for these operations including circuitId, sessionid and apiSessionId should now be in log
      messages regardless of whether tracing is enabled
    * Tracing is enabled for a given duration, which defaults to 10 minutes

## Breaking Changes

Fabric sessions renamed to circuits. External integrators may be impacted by changes to events. See below for details.

### Ziti CLI

Commands under `ziti edge` now reserve the `-i` flag for specifying client identity. Any command line argumet which
previously had a `-i` short version now only has a long version.

For consistency, policy roles parameters must all be specified in long form

This includes the following flags:

* ziti edge create edge-router-policy --identity-roles --edge-router-roles
* ziti edge update edge-router-policy --identity-roles --edge-router-roles
* ziti edge create service-policy --identity-roles --service-roles
* ziti edge update service-policy --identity-roles --service-roles
* ziti edge create service-edge-router-policy --service-roles --edge-router-roles
* ziti edge update service-edge-router-policy --service-roles --edge-router-roles
* ziti edge create posture-check mfa --ignore-legacy
* ziti edge update posture-check mfa --ignore-legacy
* ziti edge update authenticator updb --identity
* ziti egde update ca --identity-atributes (now -a)

The `ziti edge` commands now store session credentials in a new location and new format. Existing sessions will be
ignored.

The `ziti edge controller` command was previously deprecated and has now been removed. All commands that were previously
available under `ziti edge controller` are available under `ziti edge`.

## Fabric Sessions renamed to Circuits

Previously we had three separate entities named session: fabric sessions, edge sessions and edge API sessions. In order
to reduce confusion, fabric sessions have been renamed to circuits. This has the following impacts:

* ziti-fabric CLI
    * `list sessions` renamed to `list circuits`
    * `remove session` renamed to `remove circuit`
    * `stream sessions` renamed to `stream circuits`
* Config properties
    * In the controller config, under `networks`, `createSessionRetries` is now `createCircuitRetries`
    * In the router config, under xgress dialer/listener options, `getSessionTimeout` is now `getCircuitTimeout`
    * In the router config, under xgress dialer/listener options, `sessionStartTimeout` is now `circuitStartTimeout`
    * In the router, under `forwarder`, `idleSessionTimeout` is now `idleCircuitTimeout`

In the context of the fabric there was an existing construct call `Circuit` which has now been renamed to `Path`. This
may be visible in a few `ziti-fabric` CLI outputs

### Event changes

Previously the fabric had session events. It now has circuit events instead. These events have the `fabric.circuits`
namespace. The `circuitUpdated` event type is now the `pathUpdated` event.

```
type CircuitEvent struct {
	Namespace string    `json:"namespace"`
	EventType string    `json:"event_type"`
	CircuitId string    `json:"circuit_id"`
	Timestamp time.Time `json:"timestamp"`
	ClientId  string    `json:"client_id"`
	ServiceId string    `json:"service_id"`
	Path      string    `json:"circuit"`
}
```

Additionally the Usage events now have `circuit_id` instead of `session_id`. The usage events also have a new `version`
field, which is set to 2.

# Pending Link Timeout

Previously whenever a router connected we'd look for new links possiblities and create new links between routers where
any were missing. If lots of routers connected at the same time, we might create duplicate links because the links
hadn't been reported as established yet. Now we'll checking for links in Pending state, and if they haven't hit a
configurable timeout, we won't create another link.

The new config property is `pendingLinkTimeoutSeconds` in the controller config file under `network`, and defaults to 10
seconds.

## Enhanced CLI Login Functionality

### Server Trust

#### Untrusted Servers

If you don't provide a certificates file when logging in, the server's well known certificates will now be pulled from
the server and you will be prompted if you want to use them. If certs for the host have previously been retrieved they
will be used. Certs stored locally will be checked against the certs on the server when logging in. If a difference is
found, the user will be notified and asked if they want to update the local certificate cache.

If you provide certificates during login, the server's certificates will not be checked or downloaded. Locally cached
certificates for that host will not be used.

#### Trusted Servers

If working with a server which is using certs that your OS already recognizes, nothing will change. No cert needs to be
provided and the server's well known certs will not be downloaded.

### Identities

The Ziti CLI now suports multiple identities. An identity can be specified using `--cli-identity` or `-i`.

Example commands:

```
$ ziti edge login -i dev localhost:1280
Enter username: admin
Enter password: 
Token: 76ff81b4-b528-4e2c-ad73-dcb0a39b6489
Saving identity 'dev' to ~/.config/ziti/ziti-cli.json

$ ziti edge -i dev list services
id: -JucPW0kGR    name: ssh    encryption required: true    terminator strategy: smartrouting    role attributes: ["ssh"]
results: 1-1 of 1
```

If no identity is specified, a default will be used. The default identity is `default`.

#### Switching Default Identity

The default identity can be changed with the `ziti edge use` command.

The above example could also be accomplished as follows:

```
$ ziti edge use dev
Settting identity 'dev' as default in ~/.config/ziti/ziti-cli.json

$ ziti edge login localhost:1280
Enter username: admin
Enter password: 
Token: e325d91c-a452-4454-a733-cfad88bfa356
Saving identity 'dev' to ~/.config/ziti/ziti-cli.json

$ ziti edge list services
id: -JucPW0kGR    name: ssh    encryption required: true    terminator strategy: smartrouting    role attributes: ["ssh"]
results: 1-1 of 1

$ ziti edge use default
Settting identity 'default' as default in ~/.config/ziti/ziti-cli.json
```

`ziti edge use` without an argument will list logins you have made.

```
$ ziti edge use
id:      default | current:  true | read-only:  true | urL: https://localhost:1280/edge/management/v1
id:        cust1 | current: false | read-only: false | urL: https://customer1.com:443/edge/management/v1
```

#### Logout

You can now also clear locally stored credentials using `ziti edge logout`

```
$ ziti edge -i cust1 logout  
Removing identity 'cust1' from ~/.config/ziti/ziti-cli.json
```

#### Read-Only Mode

When logging in one can mark the identity as read-only. This is a client side enforced flag which will attempt to make
sure only read operations are performed by this session.

```
$ ziti edge login --read-only localhost:1280
Enter username: admin
Enter password: 
Token: 966192c6-fb7f-481e-8230-dcef157770ef
Saving identity 'default' to ~/.config/ziti/ziti-cli.json

$ ziti edge list services
id: -JucPW0kGR    name: ssh    encryption required: true    terminator strategy: smartrouting    role attributes: ["ssh"]
results: 1-1 of 1

$ ziti edge create service test
error: this login is marked read-only, only GET operations are allowed
```

NOTE: This is not guaranteed to prevent database changes. It is meant to help prevent accidental changes, if the wrong
profile is accidentally used. Caution should always be exercised when working with sensitive data!

#### Login via Token

If you already have an API session token, you can use that to create a client identity using the new `--token` flag.
When using `--token` the saved identity will be marked as read-only unless `--read-only=false` is specified. This is
because if you only have a token and not full credentials, it's more likely that you're inspecting a system to which you
have limited privileges.

```
$ ziti edge login localhost:1280 --token c9f37575-f660-409b-b731-5a256d74a931
NOTE: When using --token the saved identity will be marked as read-only unless --read-only=false is provided
Saving identity 'default' to ~/.config/ziti/ziti-cli.json
```

Using this option will still check the server certificates to see if they need to be downloaded and/or compare them with
locally cached certificates.

# Release 0.21.0

## Semantic now Required for policies (BREAKING CHANGE)

Previouxly semantic was optional when creating or updating policies (POST or PUT), defaulting to `AllOf` when not
specified. It is now required.

## What's New

* Bug fix: Using PUT for policies without including the semantic would cause them to be evaluated using the AllOf
  semantic
* Bug fix: Additional concurrency fix in posture data
* Feature: Ziti CLI now supports a comprehensive set of `ca` and `cas` options
* Feature: `ziti ps` now supports `set-channel-log-level` and `clear-channel-log-level` operations
* Change: Previouxly semantic was optional when creating or updating policies (POST or PUT), defaulting to `AllOf` when
  not specified. It is now required.

# Release 0.20.14

## What's New

* Bug fix: Posture timeouts (i.e. MFA timeouts) would not apply to the first session of an API session
* Bug fix: Fix panic during API Session deletion
* Bug fix: DNS entries in embedded DNS server in go tunneler apps were not being cleaned up
* Feature: Ziti CLI now supports attribute updates on MFA posture checks
* Feature: Posture queries now support `timeout` and `timeoutRemaining`

# Release 0.20.13

## What's New

* Bug fix: [edge#712](https://github.com/openziti/edge/issues/712)
    * NF-INTERCEPT chain was getting deleted when any intercept was stopped, not when all intercepts were stopped
    * IP address could get re-used across DNS entries. Added DNS cache flush on startup to avoid this
    * IP address cleanup was broken as all services would see last assigned IP
* Bug fix: Introduce delay when closing xgress peer after receiving unroute if end of session not yet received
* Feature: Can now search relevant entities by role attributes
    * Services, edge routers and identities can be search by role attribute.
      Ex: `ziti edge list services 'anyOf(roleAttributes) = "one"'`
    * Polices can be searched by roles. Ex: `ziti edge list service-policies 'anyOf(identityRoles) = "#all"'`

# Release 0.20.12

## What's New

* Bug fix: [edge#641](https://github.com/openziti/edge/issues/641)Management and Client API nested resources now
  support `limit` and `offset` outside of `filter` as query params
* Feature: MFA Timeout Options

## MFA Timeout Options

The MFA posture check now supports three options:

* `timeoutSeconds` - the number of seconds before an MFA TOTP will need to be provided before the posture check begins
  to fail (optional)
* `promptOnWake` - reduces the current timeout to 5m (if not less than already) when an endpoint reports a "wake"
  event (optional)
* `promptOnUnlock` - reduces the current timeout to 5m (if not less than already) when an endpoint reports an "unlock"
  event (optional)
* `ignoreLegacyEndpoints` - forces all other options to be ignored for legacy clients that do not support event state (
  optional)

Event states, `promptOnWake` and `promptOnUnlock` are only supported in Ziti C SDK v0.20.0 and later. Individual ZDE/ZME
clients may take time to update. If older endpoint are used with the new MFA options `ignoreLegacyEndpoints` allows
administrators to decide how those clients should be treated. If `ignoreLegacyEndpoints` is `true`, they will not be
subject to timeout or wake events.

# Release 0.20.11

* Bug fix: CLI Admin create/update/delete for UPDB authenticators now function properly
* Maintenance: better logging [sdk-golang#161](https://github.com/openziti/sdk-golang/pull/161)
  and [edge#700](https://github.com/openziti/edge/pull/700)
* Bug fix: [sdk-golang#162](https://github.com/openziti/sdk-golang/pull/162) fix race condition on close of ziti
  connections

# Release 0.20.10

## What's New

* Bug fix: patch for process multi would clear information
* Bug fix: [ziti#420](https://github.com/openziti/ziti/issues/420) fix ziti-tunnel failover with multiple interfaces
  when once becomes unavailable
* Bug fix: [edge#670](https://github.com/openziti/edge/issues/670) fix ziti-tunnel issue where address were left
  assigned to loopback after clean shutdown
* Bug fix: race condition in edge session sync could cause router panic. Regression since 0.20.9
* Bug fix: terminator updates and deletes from the combined router/tunneler weren't working
* Feature: Router health checks
* Feature: Controller health check

## Router Health Checks

Routers can now enable an HTTP health check endpoint. The health check is configured in the router config file with the
new `healthChecks` section.

```
healthChecks:
    ctrlPingCheck:
        # How often to ping the controller over the control channel. Defaults to 30 seconds
        interval: 30s
        # When to timeout the ping. Defaults to 15 seconds
        timeout: 15s
        # How long to wait before pinging the controller. Defaults to 15 seconds
        initialDelay: 15s
```

The health check endpoint is configured via XWeb, same as in the controller. As section like the following can be added
to the router config to enable the endpoint.

```
web:
  - name: health-check
    bindPoints:
      - interface: 127.0.0.1:8081
        address: 127.0.0.1:8081
    apis:
      - binding: health-checks
```

The health check output will look like this:

```
$ curl -k https://localhost:8081/health-checks
{
    "data": {
        "checks": [
            {
                "healthy": true,
                "id": "controllerPing",
                "lastCheckDuration": "767.381µs",
                "lastCheckTime": "2021-06-21T16:22:36-04:00"
            }
        ],
        "healthy": true
    },
    "meta": {}
}

```

The endpoint will return a 200 if the health checks are passing and 503 if they are not.

# Controller Health Check

Routers can now enable an HTTP health check endpoint. The health check is configured in the router config file with the
new `healthChecks` section.

```
healthChecks:
    boltCheck:
        # How often to check the bolt db. Defaults to 30 seconds
        interval: 30s
        # When to timeout the bolt db check. Defaults to 15 seconds
        timeout: 15s
        # How long to wait before starting bolt db checks. Defaults to 15 seconds
        initialDelay: 15s
```

The health check endpoint is configured via XWeb. In order to enable the health check endpoint, add it **first** to the
list of apis.

```
    apis:
      # binding - required
      # Specifies an API to bind to this webListener. Built-in APIs are
      #   - edge-management
      #   - edge-client
      #   - fabric-management
      - binding: health-checks
        options: { }
      - binding: edge-management
        # options - variable optional/required
        # This section is used to define values that are specified by the API they are associated with.
        # These settings are per API. The example below is for the `edge-api` and contains both optional values and
        # required values.
        options: { }
      - binding: edge-client
        options: { }

```

The health check output will look like this:

```
$ curl -k https://localhost:1280/health-checks
{
    "data": {
        "checks": [
            {
                "healthy": true,
                "id": "bolt.read",
                "lastCheckDuration": "27.46µs",
                "lastCheckTime": "2021-06-21T17:32:31-04:00"
            }
        ],
        "healthy": true
    },
    "meta": {}
}

```

# Release 0.20.9

## What's New

* Bug fix: router session sync would fail if it took longer than a second
* Bug fix: API sessions created during session sync could get thrown out when session sync was finalized
* Bug fix: Update of identity defaultHostingCost and defaultHostingPrecedence didn't work
* Improvement: List identities is faster as it no longer always iterates through all api-sessions
* Improvement: API Session enforcer now batches deletes of session for better performance

# Release 0.20.8

## What's New

* 0.20.7 was missing the most up-to-date version of the openziti/edge library dependency

# Release 0.20.7

## What's New

* Xlink now supports to a boolean `split` option to enable/disable separated payload and ack channels.
* Router identity now propagated through the link establishment plumbing. Will facilitate
  router-directed `transport.Configuration` profiles in a future release.
* Bug fix: tunneler identity appData wasn't propagated to tunneler/router
* Bug fix: API session updates were only being sent to one router (regression since 0.20.4)
* Bug fix: API session enforcer wasn't being started (regression since 0.20.0)
* Bug fix: Setting per identity service costs/precedences didn't work with PATCH

### Split Xlink Payload/Ack Channels

Split payload and ack channels are enabled by default, preserving the behavior of previous releases. To disable split
channels, merge the following stanza into your router configuration:

```
link:
  dialers:
    - binding:              transport
      split:                false
```

# Release 0.20.6

## What's New

* Bug fix: Revert defensive Edge Router disconnect protection in Edge

# Release 0.20.5

## What's New

* Bug fix: Fix panic on double chan close that can occur when edge routers disconnect/reconnect in rapid succession
* Bug fix: Fix defaults for enrollment durations when not specified (would default near 0 values)

# Release 0.20.4

## What's New

* Bug fix: Fix a deadlock that can occur if Edge Routers disconnect during session synchronization or update processes
* Bug fix: Fix URL for CAS create in Ziti CLI

# Release 0.20.3

## What's New

* Bug fix: Update of identity appData wasn't working
* Bug fix: Terminator updates failed if cost wasn't specified
* Bug fix: Control channel handler routines were exiting on error instead of just closing peer and continuing

# Release 0.20.2

## What's New

* ziti-router will now emit a stackdump before exiting when it receives a SIGQUIT
* ziti ps stack now takes a --stack-timeout and will quit after the specified timeout if the stack dump hasn't completed
  yet
* ziti now supports posture check types of process multi
* Fixes a bug in Ziti Management API where posture checks of type process multi were missing their base entity
  information (createdAt, updatedAt, etc.)

# Release 0.20.1

## What's New

* Fixes a bug in the GO sdk which could cause panic by return nil connection and nil error
* [ziti#170](https://github.com/openziti/ziti/issues/170) Fixes the service poll refresh default for ziti-tunnel host
  mode
* Fixes a deadlock in control channel reconnect logic triggerable when network path to controller is unreliable

# Release 0.20.0

## What's New

* Fix bug in router/tunneler where only first 10 services would get picked up for intercepting/hosting
* Fix bug in router/tunneler where we'd process services multiple times on service add/remove/update
* Historical Changelog Split
* Edge Management REST API Transit Router Deprecation
* Edge REST API Split & Configuration Changes

### Historical Changelog Split

Changelogs for previous minor versions are now split into their own files under `/changelogs`.

### Edge Management REST API Transit Router Deprecation

The endpoint `/transit-routers` is now `/routers`. Use of the former name is considered deprecated. This endpoint only
affects the new Edge Management API.

### Edge REST API Split

The Edge REST API has now been split into two APIs: The Edge Client API and the Edge Management API. There are now two
Open API 2.0 specifications present in the `edge` repository under `/specs/client.yml`
and `/specs/management.yml`. These two files are generated (see the scripts in `/scripts/`) from decomposed YAML source
files present in `/specs/source`.

The APIs are now hosted on separate URL paths:

- Client API: `/edge/client/v1`
- Management API: `/edge/management/v1`

Legacy path support is present for the Client API only. The Management API does not support legacy URL paths. The Client
API Legacy paths that are supported are as follows:

- No Prefix: `/*`
- Edge Prefix: `/edge/v1/*`

This support is only expected to last until all Ziti SDKs move to using the new prefixed paths and versions that do not
reach the end of their lifecycle. After that time, support will be removed. It is highly  
suggested that URL path prefixes be updated or dynamically looked up via the `/version` endpoint (see below)

#### Client and Management API Capabilities

The Client API represents only functionality required by and endpoint to connected to and use services. This API
services Ziti SDKs.

The Management API represents all administrative configuration capabilities. The Management API is meant to be used by
the Ziti Admin Console (ZAC) or other administrative integrations.

*Client API Endpoints*

- `/edge/client/v1/`
- `/edge/client/v1/.well-known/est/cacerts`
- `/edge/client/v1/authenticate`
- `/edge/client/v1/authenticate/mfa`
- `/edge/client/v1/current-api-session`
- `/edge/client/v1/current-api-session/certificates`
- `/edge/client/v1/current-api-session/certificates/{id}`
- `/edge/client/v1/current-api-session/service-updates`
- `/edge/client/v1/current-identity`
- `/edge/client/v1/current-identity/authenticators`
- `/edge/client/v1/current-identity/authenticators/{id}`
- `/edge/client/v1/current-identity/edge-routers`
- `/edge/client/v1/current-identity/mfa`
- `/edge/client/v1/current-identity/mfa/qr-code`
- `/edge/client/v1/current-identity/mfa/verify`
- `/edge/client/v1/current-identity/mfa/recovery-codes`
- `/edge/client/v1/enroll`
- `/edge/client/v1/enroll/ca`
- `/edge/client/v1/enroll/ott`
- `/edge/client/v1/enroll/ottca`
- `/edge/client/v1/enroll/updb`
- `/edge/client/v1/enroll/erott`
- `/edge/client/v1/enroll/extend/router`
- `/edge/client/v1/posture-response`
- `/edge/client/v1/posture-response-bulk`
- `/edge/client/v1/protocols`
- `/edge/client/v1/services`
- `/edge/client/v1/services/{id}`
- `/edge/client/v1/services/{id}/terminators`
- `/edge/client/v1/sessions`
- `/edge/client/v1/sessions/{id}`
- `/edge/client/v1/specs`
- `/edge/client/v1/specs/{id}`
- `/edge/client/v1/specs/{id}/spec`
- `/edge/client/v1/version`

*Management API Endpoints*

- `/edge/management/v1/`
- `/edge/management/v1/api-sessions`
- `/edge/management/v1/api-sessions/{id}`
- `/edge/management/v1/authenticate`
- `/edge/management/v1/authenticate/mfa`
- `/edge/management/v1/authenticators`
- `/edge/management/v1/authenticators/{id}`
- `/edge/management/v1/cas`
- `/edge/management/v1/cas/{id}`
- `/edge/management/v1/cas/{id}/jwt`
- `/edge/management/v1/cas/{id}/verify`
- `/edge/management/v1/config-types`
- `/edge/management/v1/config-types/{id}`
- `/edge/management/v1/config-types/{id}/configs`
- `/edge/management/v1/configs`
- `/edge/management/v1/configs/{id}`
- `/edge/management/v1/current-api-session`
- `/edge/management/v1/current-identity`
- `/edge/management/v1/current-identity/authenticators`
- `/edge/management/v1/current-identity/authenticators/{id}`
- `/edge/management/v1/current-identity/mfa`
- `/edge/management/v1/current-identity/mfa/qr-code`
- `/edge/management/v1/current-identity/mfa/verify`
- `/edge/management/v1/current-identity/mfa/recovery-codes`
- `/edge/management/v1/database/snapshot`
- `/edge/management/v1/database/check-data-integrity`
- `/edge/management/v1/database/fix-data-integrity`
- `/edge/management/v1/database/data-integrity-results`
- `/edge/management/v1/edge-router-role-attributes`
- `/edge/management/v1/edge-routers`
- `/edge/management/v1/edge-routers/{id}`
- `/edge/management/v1/edge-routers/{id}/edge-router-policies`
- `/edge/management/v1/edge-routers/{id}/identities`
- `/edge/management/v1/edge-routers/{id}/service-edge-router-policies`
- `/edge/management/v1/edge-routers/{id}/services`
- `/edge/management/v1/edge-router-policies`
- `/edge/management/v1/edge-router-policies/{id}`
- `/edge/management/v1/edge-router-policies/{id}/edge-routers`
- `/edge/management/v1/edge-router-policies/{id}/identities`
- `/edge/management/v1/enrollments`
- `/edge/management/v1/enrollments/{id}`
- `/edge/management/v1/identities`
- `/edge/management/v1/identities/{id}`
- `/edge/management/v1/identities/{id}/edge-router-policies`
- `/edge/management/v1/identities/{id}/service-configs`
- `/edge/management/v1/identities/{id}/service-policies`
- `/edge/management/v1/identities/{id}/edge-routers`
- `/edge/management/v1/identities/{id}/services`
- `/edge/management/v1/identities/{id}/policy-advice/{serviceId}`
- `/edge/management/v1/identities/{id}/posture-data`
- `/edge/management/v1/identities/{id}/failed-service-requests`
- `/edge/management/v1/identities/{id}/mfa`
- `/edge/management/v1/identity-role-attributes`
- `/edge/management/v1/identity-types`
- `/edge/management/v1/identity-types/{id}`
- `/edge/management/v1/posture-checks`
- `/edge/management/v1/posture-checks/{id}`
- `/edge/management/v1/posture-check-types`
- `/edge/management/v1/posture-check-types/{id}`
- `/edge/management/v1/service-edge-router-policies`
- `/edge/management/v1/service-edge-router-policies/{id}`
- `/edge/management/v1/service-edge-router-policies/{id}/edge-routers`
- `/edge/management/v1/service-edge-router-policies/{id}/services`
- `/edge/management/v1/service-role-attributes`
- `/edge/management/v1/service-policies`
- `/edge/management/v1/service-policies/{id}`
- `/edge/management/v1/service-policies/{id}/identities`
- `/edge/management/v1/service-policies/{id}/services`
- `/edge/management/v1/service-policies/{id}/posture-checks`
- `/edge/management/v1/services`
- `/edge/management/v1/services/{id}`
- `/edge/management/v1/services/{id}/configs`
- `/edge/management/v1/services/{id}/service-edge-router-policies`
- `/edge/management/v1/services/{id}/service-policies`
- `/edge/management/v1/services/{id}/identities`
- `/edge/management/v1/services/{id}/edge-routers`
- `/edge/management/v1/services/{id}/terminators`
- `/edge/management/v1/sessions`
- `/edge/management/v1/sessions/{id}`
- `/edge/management/v1/sessions/{id}/route-path`
- `/edge/management/v1/specs`
- `/edge/management/v1/specs/{id}`
- `/edge/management/v1/specs/{id}/spec`
- `/edge/management/v1/summary`
- `/edge/management/v1/terminators`
- `/edge/management/v1/terminators/{id}`
- `/edge/management/v1/routers`
- `/edge/management/v1/transit-routers`
- `/edge/management/v1/routers/{id}`
- `/edge/management/v1/transit-routers/{id}`
- `/edge/management/v1/version`

#### XWeb Support & Configuration Changes

The underlying framework used to host the Edge REST API has been moved into a new library that can be found in
the `fabric` repository under the module name `xweb`. XWeb allows arbitrary APIs and website capabilities to be hosted
on one or more http servers bound to any number of network interfaces and ports.

The main result of this is that the Edge Client and Management APIs can be hosted on separate ports or even on separate
network interfaces if desired. This allows for configurations where the Edge Management API is not accessible outside of
localhost or is only presented to network interfaces that are inwardly facing.

The introduction of XWeb has necessitated changes to the controller configuration. For a full documented example see the
file `/etc/ctrl.with.edge.yml` in this repository.

##### Controller Configuration: Edge Section

The Ziti Controller configuration `edge` YAML section remains as a shared location for cross-API settings. It however,
does not include HTTP settings which are now configured in the `web` section.

Additionally, all duration configuration values must be specified in `<integer><unit>` durations. For example

- "5m" for five minutes
- "100s" for one hundred seconds

```
# By having an 'edge' section defined, the ziti-controller will attempt to parse the edge configuration. Removing this
# section, commenting out, or altering the name of the section will cause the edge to not run.
edge:
  # This section represents the configuration of the Edge API that is served over HTTPS
  api:
    #(optional, default 90s) Alters how frequently heartbeat and last activity values are persisted
    # activityUpdateInterval: 90s
    #(optional, default 250) The number of API Sessions updated for last activity per transaction
    # activityUpdateBatchSize: 250
    # sessionTimeout - optional, default 10m
    # The number of minutes before an Edge API session will timeout. Timeouts are reset by
    # API requests and connections that are maintained to Edge Routers
    sessionTimeout: 30m
    # address - required
    # The default address (host:port) to use for enrollment for the Client API. This value must match one of the addresses
    # defined in this webListener's bindPoints.
    address: 127.0.0.1:1280
  # enrollment - required
  # A section containing settings pertaining to enrollment.
  enrollment:
    # signingCert - required
    # A Ziti Identity configuration section that specifically makes use of the cert and key fields to define
    # a signing certificate from the PKI that the Ziti environment is using to sign certificates. The signingCert.cert
    # will be added to the /.well-known CA store that is used to bootstrap trust with the Ziti Controller.
    signingCert:
      cert: ${ZITI_SOURCE}/ziti/etc/ca/intermediate/certs/intermediate.cert.pem
      key: ${ZITI_SOURCE}/ziti/etc/ca/intermediate/private/intermediate.key.decrypted.pem
    # edgeIdentity - optional
    # A section for identity enrollment specific settings
    edgeIdentity:
      # durationMinutes - optional, default 5m
      # The length of time that a Ziti Edge Identity enrollment should remain valid. After
      # this duration, the enrollment will expire and not longer be usable.
      duration: 5m
    # edgeRouter - Optional
    # A section for edge router enrollment specific settings.
    edgeRouter:
      # durationMinutes - optional, default 5m
      # The length of time that a Ziti Edge Router enrollment should remain valid. After
      # this duration, the enrollment will expire and not longer be usable.
      duration: 5m

```

##### Controller Configuration: Web Section

The `web` section now allows Ziti APIs to be configured on various network interfaces and ports according to deployment
requirements. The `web` section is an array of configuration that defines `WebListener`s. Each `WebListener` has its own
HTTP configuration, `BindPoint`s, identity override, and `API`s which are referenced by `binding` name.

Each `WebListener` maps to at least one HTTP server that will be bound on at least one `BindPoint`
(network interface/port combination and external address) and will host one or more `API`s defined in the `api`
section. `API`s are configured by `binding` name. The following `binding` names are currently supported:

- Edge Client API: `edge-client`
- Edge Management API: `edge-management`

An example `web` section that places both the Edge Client and Management APIs on the same
`BindPoint`s would be:

```
# web 
# Defines webListeners that will be hosted by the controller. Each webListener can host many APIs and be bound to many
# bind points.
web:
  # name - required
  # Provides a name for this listener, used for logging output. Not required to be unique, but is highly suggested.
  - name: all-apis-localhost
    # bindPoints - required
    # One or more bind points are required. A bind point specifies an interface (interface:port string) that defines
    # where on the host machine the webListener will listen and the address (host:port) that should be used to
    # publicly address the webListener(i.e. my-domain.com, localhost, 127.0.0.1). This public address may be used for
    # incoming address resolution as well as used in responses in the API.
    bindPoints:
      #interface - required
      # A host:port string on which network interface to listen on. 0.0.0.0 will listen on all interfaces
      - interface: 127.0.0.1:1280
        # address - required
        # The public address that external incoming requests will be able to resolve. Used in request processing and
        # response content that requires full host:port/path addresses.
        address: 127.0.0.1:1280
    # identity - optional
    # Allows the webListener to have a specific identity instead of defaulting to the root `identity` section.
    #    identity:
    #      cert:                 ${ZITI_SOURCE}/ziti/etc/ca/intermediate/certs/ctrl-client.cert.pem
    #      server_cert:          ${ZITI_SOURCE}/ziti/etc/ca/intermediate/certs/ctrl-server.cert.pem
    #      key:                  ${ZITI_SOURCE}/ziti/etc/ca/intermediate/private/ctrl.key.pem
    #      ca:                   ${ZITI_SOURCE}/ziti/etc/ca/intermediate/certs/ca-chain.cert.pem
    # options - optional
    # Allows the specification of webListener level options - mainly dealing with HTTP/TLS settings. These options are
    # used for all http servers started by the current webListener.
    options:
      # idleTimeoutMs - optional, default 5000ms
      # The maximum amount of idle time in milliseconds allowed for pipelined HTTP requests. Setting this too high
      # can cause resources on the host to be consumed as clients remain connected and idle. Lowering this value
      # will cause clients to reconnect on subsequent HTTPs requests.
      idleTimeout: 5000ms  #http timeouts, new
      # readTimeoutMs - optional, default 5000ms
      # The maximum amount of time in milliseconds http servers will wait to read the first incoming requests. A higher
      # value risks consuming resources on the host with clients that are acting bad faith or suffering from high latency
      # or packet loss. A lower value can risk losing connections to high latency/packet loss clients.
      readTimeout: 5000ms
      # writeTimeoutMs - optional, default 10000ms
      # The total maximum time in milliseconds that the http server will wait for a single requests to be received and
      # responded too. A higher value can allow long running requests to consume resources on the host. A lower value
      # can risk ending requests before the server has a chance to respond.
      writeTimeout: 100000ms
      # minTLSVersion - optional, default TSL1.2
      # The minimum version of TSL to support
      minTLSVersion: TLS1.2
      # maxTLSVersion - optional, default TSL1.3
      # The maximum version of TSL to support
      maxTLSVersion: TLS1.3
    # apis - required
    # Allows one or more APIs to be bound to this webListener
    apis:
      # binding - required
      # Specifies an API to bind to this webListener. Built-in APIs are
      #   - edge-management
      #   - edge-client
      #   - fabric-management
      - binding: edge-management
        # options - variable optional/required
        # This section is used to define values that are specified by the API they are associated with.
        # These settings are per API. The example below is for the `edge-api` and contains both optional values and
        # required values.
        options: { }
      - binding: edge-client
        options: { }
  - name: test-remove-me
    bindPoints:
      - interface: 127.0.0.1:1281
        address: 127.0.0.1:1281
    options: { }
    apis:
      - binding: edge-management
        options: { }
      - binding: edge-client
        options: { }
```

All optional values are defaulted. The smallest configuration possible that places the Edge Client and Managements APIs
on the same `BindPoint` would be:

```
web:
  - name: client-management-localhost
    bindPoints:
      - interface: 127.0.0.1:1280
        address: 127.0.0.1:1280
    options: { }
    apis:
      - binding: edge-management
        options: { }
      - binding: edge-client
        options: { }
```

The following examples places the Management API on localhost and the Client API on all available interface and
advertised as `client.api.ziti.dev:1280`:

```
web:
  - name: client-all-interfaces
    bindPoints:
      - interface: 0.0.0.0:1280
        address: client.api.ziti.dev:1280
    options: { }
    apis:
      - binding: edge-client
        options: { }
  - name: management-local-only
    bindPoints:
      - interface: 127.0.0.1:1234
        address: 127.0.0.1:1234
    options: { }
    apis:
      - binding: edge-management
        options: { }
```

#### Version Endpoint Updates

All Edge APIs support the `/version` endpoint and report all the APIs supported by the controller. Each API now has
a `binding` (string name) which is a global handle for that API's capabilities. See the current list below

- Client API: `edge-client`, `edge`
- Management API: `edge-management`

Note: `edge` is an alias of `edge-client` for the `/version` endpoint only. It is considered deprecated.

These `bind names` can be used to parse the information returned by the `/version` endpoint to obtain the most correct
URL path for each API and version present. At a future date, other APIs with new `binding`s
(e.g. 'fabric-management` or 'fabric') or new versions may be added to this endpoint.

Versions prior to 0.20 of the Edge Controller reported the following:

```
{
    "data": {
        "apiVersions": {
            "edge": {
                "v1": {
                    "path": "/edge/v1"
                }
            }
        },
        "buildDate": "2020-08-11 19:48:57",
        "revision": "e4ae43213a8d",
        "runtimeVersion": "go1.14.7",
        "version": "v0.16.0"
    },
    "meta": {}
}
```

Note: `/edge/v1` is deprecated

Version 0.20 and later report:

```
{
    "data": {
        "apiVersions": {
            "edge": {
                "v1": {
                    "apiBaseUrls": [
                        "https://127.0.0.1:1280/edge/client/v1",
                        "https://127.0.0.1:1281/edge/client/v1"
                    ],
                    "path": "/edge/client/v1"
                }
            },
            "edge-client": {
                "v1": {
                    "apiBaseUrls": [
                        "https://127.0.0.1:1280/edge/client/v1",
                        "https://127.0.0.1:1281/edge/client/v1"
                    ],
                    "path": "/edge/client/v1"
                }
            },
            "edge-management": {
                "v1": {
                    "apiBaseUrls": [
                        "https://127.0.0.1:1280/edge/management/v1",
                        "https://127.0.0.1:1281/edge/management/v1"
                    ],
                    "path": "/edge/management/v1"
                }
            }
        },
        "buildDate": "2020-01-01 01:01:01",
        "revision": "local",
        "runtimeVersion": "go1.16.2",
        "version": "v0.0.0"
    },
    "meta": {}
}.

```
