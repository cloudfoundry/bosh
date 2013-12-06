## BOSH Agent written in Go

```
PATH=.../s3cli/out:$PATH bin/run -I dummy -P ubuntu
```

### Running locally

To start server locally:
```
gem install nats
nats-server
```

To subscribe:
```
nats-sub '>' -s nats://localhost:4222
```

To publish:
```
nats-pub agent.123-456-789 '{"method":"apply","arguments":[{"packages":[{"name":"package-name", "version":"package-version"}]}]}' -s nats://localhost:4222
```
