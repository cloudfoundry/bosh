package nats

// BuildTLSConfig exposes buildTLSConfig for use in external test packages.
// This file is compiled only during test runs.
var BuildTLSConfig = buildTLSConfig

// ConnectFunc is a pointer to the connectFunc variable so tests can replace
// it with a fake and restore the original afterwards.
var ConnectFunc = &connectFunc

// RetryWait is a pointer to the retryWait variable so tests can set a
// sub-millisecond interval and keep the retry suite fast.
var RetryWait = &retryWait
