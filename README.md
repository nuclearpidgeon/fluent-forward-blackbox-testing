# Fluent Forward protocol blackbox probe testing

This repo houses some scripts for testing methods to "blackbox probe" a Fluent Forward logging server.

The Fluent Forward protocol, defined at https://github.com/fluent/fluentd/wiki/Forward-Protocol-Specification-v1, is used by [Fluentbit](https://fluentbit.io/) and [Fluentd](https://www.fluentd.org/) for transferring timestamped structures logs from a log source to a log server, using [msgpack](https://github.com/msgpack/msgpack) structures over TCP.

* Forward input for fluentbit: https://docs.fluentbit.io/manual/pipeline/inputs/forward
* Forward input for fluentd: https://docs.fluentd.org/input/forward

Normally Fluent Forward just accepts a stream of msgpack records over the TCP bytestream and doesn't provide any acknowledgement of what it receives. This makes the usual approaches to blackbox probing a server a bit redundant because you do not have an ironclad guarantee that the server process has received the packets you have sent, especially if load balancing is involved.

The protocol does also specify a 'heartbeat' mechanism over UDP (_"Client MAY send UDP packets to the same port of connection, to check existence of Servers."_). However, even as of v3.1, fluentbit does not seem to support these UDP heartbeats.

Additionally, there is provision in the protocol for a "handshake". However looking in the Fluentbit Forward input plugin connection handling, the HELO/PING/PONG handshake seems to only apply for servers set up with a shared key: https://github.com/fluent/fluent-bit/blob/v3.1.9/plugins/in_forward/fw_conn.c#L145 .

However, the protocol specifies a "chunk" option that can be used to get the server to respond to a batch of messages sent up to it. This forms the basis of the testing performed in this repo to see if the ack can be caught in a way to get a more reliable availability check probe.

## Netcat approach

[`forward-nc-test.sh`](/forward-nc-test.sh) tests the probing approach using `json2msgpack` to construct a forward protocol message that has the `chunk` option set, to deliver to a fluentbit server running under docker, and then showing the bytes that come back out of the TCP connection with `xxd`.

The response is also saved into a `resp.bin` file. You can run `msgpack2json < resp.bin` to see what this looks like in JSON format.

## Blackbox probe approach

[`forward-blackbox_exporter-tcp-test.sh`](/forward-blackbox_exporter-tcp-test.sh) tests the `tcp` probe mode of the [Prometheus blackbox_exporter](https://github.com/prometheus/blackbox_exporter/) via the config in [`tcp-forward-probe.yml`](/tcp-forward-probe.yml) to see how its `query_response` `send` and `expect` options work (see https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md#tcp_probe), again targeting a fluentbit server running under docker.

Ultimately, it seems this mode just fundamentally may not work. The tcp probe's response checking uses a Go [`bufio.Scanner`](https://pkg.go.dev/bufio#Scanner) (see https://github.com/prometheus/blackbox_exporter/blob/v0.25.0/prober/tcp.go#L135) seemingly with defaults, which means it will only ever be able to work with newline-separated chunks of bytes. msgpack doesn't use newline characters/bytes as any kind of delimiter as it is a binary protocol, so it seems a custom exporter probe may be required.

## Utilities used in the scripts

* `json2msgpack` from https://github.com/ludocode/msgpack-tools
* `jq` JSON processor - https://jqlang.github.io/jq/
* `xxd` for displaying binary data - https://linux.die.net/man/1/xxd