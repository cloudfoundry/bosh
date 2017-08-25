// Copyright 2012-2016 Apcera Inc. All rights reserved.

package server

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"reflect"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	"crypto/tls"

	"github.com/nats-io/go-nats"
	"crypto/x509"
	"encoding/pem"
)

type serverInfo struct {
	Id           string `json:"server_id"`
	Host         string `json:"host"`
	Port         uint   `json:"port"`
	Version      string `json:"version"`
	AuthRequired bool   `json:"auth_required"`
	TLSRequired  bool   `json:"ssl_required"`
	MaxPayload   int64  `json:"max_payload"`
}

type mockAuth struct{}

func (m *mockAuth) Check(c ClientAuth) bool {
	return true
}

func createClientAsync(ch chan *client, s *Server, cli net.Conn) {
	go func() {
		c := s.createClient(cli)
		// Must be here to suppress +OK
		c.opts.Verbose = false
		ch <- c
	}()
}

var defaultServerOptions = Options{
	Trace:  false,
	Debug:  false,
	NoLog:  true,
	NoSigs: true,
}

func rawSetup(serverOptions Options) (*Server, *client, *bufio.Reader, string) {
	cli, srv := net.Pipe()
	cr := bufio.NewReaderSize(cli, maxBufSize)
	s := New(&serverOptions)
	if serverOptions.Authorization != "" {
		s.SetClientAuthMethod(&mockAuth{})
	}

	ch := make(chan *client)
	createClientAsync(ch, s, srv)

	l, _ := cr.ReadString('\n')

	// Grab client
	c := <-ch
	return s, c, cr, l
}

func setUpClientWithResponse() (*client, string) {
	_, c, _, l := rawSetup(defaultServerOptions)
	return c, l
}

func setupClient() (*Server, *client, *bufio.Reader) {
	s, c, cr, _ := rawSetup(defaultServerOptions)
	return s, c, cr
}

func TestClientCreateAndInfo(t *testing.T) {
	c, l := setUpClientWithResponse()

	if c.cid != 1 {
		t.Fatalf("Expected cid of 1 vs %d\n", c.cid)
	}
	if c.state != OP_START {
		t.Fatal("Expected state to be OP_START")
	}

	if !strings.HasPrefix(l, "INFO ") {
		t.Fatalf("INFO response incorrect: %s\n", l)
	}
	// Make sure payload is proper json
	var info serverInfo
	err := json.Unmarshal([]byte(l[5:]), &info)
	if err != nil {
		t.Fatalf("Could not parse INFO json: %v\n", err)
	}
	// Sanity checks
	if info.MaxPayload != MAX_PAYLOAD_SIZE ||
		info.AuthRequired || info.TLSRequired ||
		info.Port != DEFAULT_PORT {
		t.Fatalf("INFO inconsistent: %+v\n", info)
	}
}

func TestClientConnect(t *testing.T) {
	_, c, _ := setupClient()

	// Basic Connect setting flags
	connectOp := []byte("CONNECT {\"verbose\":true,\"pedantic\":true,\"ssl_required\":false}\r\n")
	err := c.parse(connectOp)
	if err != nil {
		t.Fatalf("Received error: %v\n", err)
	}
	if c.state != OP_START {
		t.Fatalf("Expected state of OP_START vs %d\n", c.state)
	}
	if !reflect.DeepEqual(c.opts, clientOpts{Verbose: true, Pedantic: true}) {
		t.Fatalf("Did not parse connect options correctly: %+v\n", c.opts)
	}

	// Test that we can capture user/pass
	connectOp = []byte("CONNECT {\"user\":\"derek\",\"pass\":\"foo\"}\r\n")
	c.opts = defaultOpts
	err = c.parse(connectOp)
	if err != nil {
		t.Fatalf("Received error: %v\n", err)
	}
	if c.state != OP_START {
		t.Fatalf("Expected state of OP_START vs %d\n", c.state)
	}
	if !reflect.DeepEqual(c.opts, clientOpts{Verbose: true, Pedantic: true, Username: "derek", Password: "foo"}) {
		t.Fatalf("Did not parse connect options correctly: %+v\n", c.opts)
	}

	// Test that we can capture client name
	connectOp = []byte("CONNECT {\"user\":\"derek\",\"pass\":\"foo\",\"name\":\"router\"}\r\n")
	c.opts = defaultOpts
	err = c.parse(connectOp)
	if err != nil {
		t.Fatalf("Received error: %v\n", err)
	}
	if c.state != OP_START {
		t.Fatalf("Expected state of OP_START vs %d\n", c.state)
	}

	if !reflect.DeepEqual(c.opts, clientOpts{Verbose: true, Pedantic: true, Username: "derek", Password: "foo", Name: "router"}) {
		t.Fatalf("Did not parse connect options correctly: %+v\n", c.opts)
	}

	// Test that we correctly capture auth tokens
	connectOp = []byte("CONNECT {\"auth_token\":\"YZZ222\",\"name\":\"router\"}\r\n")
	c.opts = defaultOpts
	err = c.parse(connectOp)
	if err != nil {
		t.Fatalf("Received error: %v\n", err)
	}
	if c.state != OP_START {
		t.Fatalf("Expected state of OP_START vs %d\n", c.state)
	}

	if !reflect.DeepEqual(c.opts, clientOpts{Verbose: true, Pedantic: true, Authorization: "YZZ222", Name: "router"}) {
		t.Fatalf("Did not parse connect options correctly: %+v\n", c.opts)
	}
}

func TestClientConnectProto(t *testing.T) {
	_, c, _ := setupClient()

	// Basic Connect setting flags, proto should be zero (original proto)
	connectOp := []byte("CONNECT {\"verbose\":true,\"pedantic\":true,\"ssl_required\":false}\r\n")
	err := c.parse(connectOp)
	if err != nil {
		t.Fatalf("Received error: %v\n", err)
	}
	if c.state != OP_START {
		t.Fatalf("Expected state of OP_START vs %d\n", c.state)
	}
	if !reflect.DeepEqual(c.opts, clientOpts{Verbose: true, Pedantic: true, Protocol: ClientProtoZero}) {
		t.Fatalf("Did not parse connect options correctly: %+v\n", c.opts)
	}

	// ProtoInfo
	connectOp = []byte(fmt.Sprintf("CONNECT {\"verbose\":true,\"pedantic\":true,\"ssl_required\":false,\"protocol\":%d}\r\n", ClientProtoInfo))
	err = c.parse(connectOp)
	if err != nil {
		t.Fatalf("Received error: %v\n", err)
	}
	if c.state != OP_START {
		t.Fatalf("Expected state of OP_START vs %d\n", c.state)
	}
	if !reflect.DeepEqual(c.opts, clientOpts{Verbose: true, Pedantic: true, Protocol: ClientProtoInfo}) {
		t.Fatalf("Did not parse connect options correctly: %+v\n", c.opts)
	}
	if c.opts.Protocol != ClientProtoInfo {
		t.Fatalf("Protocol should have been set to %v, but is set to %v", ClientProtoInfo, c.opts.Protocol)
	}

	// Illegal Option
	connectOp = []byte("CONNECT {\"protocol\":22}\r\n")
	err = c.parse(connectOp)
	if err == nil {
		t.Fatalf("Expected to receive an error\n")
	}
	if err != ErrBadClientProtocol {
		t.Fatalf("Expected err of %q, got  %q\n", ErrBadClientProtocol, err)
	}
}

func TestClientPing(t *testing.T) {
	_, c, cr := setupClient()

	// PING
	pingOp := []byte("PING\r\n")
	go c.parse(pingOp)
	l, err := cr.ReadString('\n')
	if err != nil {
		t.Fatalf("Error receiving info from server: %v\n", err)
	}
	if !strings.HasPrefix(l, "PONG\r\n") {
		t.Fatalf("PONG response incorrect: %s\n", l)
	}
}

var msgPat = regexp.MustCompile(`\AMSG\s+([^\s]+)\s+([^\s]+)\s+(([^\s]+)[^\S\r\n]+)?(\d+)\r\n`)

const (
	SUB_INDEX   = 1
	SID_INDEX   = 2
	REPLY_INDEX = 4
	LEN_INDEX   = 5
)

func checkPayload(cr *bufio.Reader, expected []byte, t *testing.T) {
	// Read in payload
	d := make([]byte, len(expected))
	n, err := cr.Read(d)
	if err != nil {
		t.Fatalf("Error receiving msg payload from server: %v\n", err)
	}
	if n != len(expected) {
		t.Fatalf("Did not read correct amount of bytes: %d vs %d\n", n, len(expected))
	}
	if !bytes.Equal(d, expected) {
		t.Fatalf("Did not read correct payload:: <%s>\n", d)
	}
}

func TestClientSimplePubSub(t *testing.T) {
	_, c, cr := setupClient()
	// SUB/PUB
	go c.parse([]byte("SUB foo 1\r\nPUB foo 5\r\nhello\r\nPING\r\n"))
	l, err := cr.ReadString('\n')
	if err != nil {
		t.Fatalf("Error receiving msg from server: %v\n", err)
	}
	matches := msgPat.FindAllStringSubmatch(l, -1)[0]
	if len(matches) != 6 {
		t.Fatalf("Did not get correct # matches: %d vs %d\n", len(matches), 6)
	}
	if matches[SUB_INDEX] != "foo" {
		t.Fatalf("Did not get correct subject: '%s'\n", matches[SUB_INDEX])
	}
	if matches[SID_INDEX] != "1" {
		t.Fatalf("Did not get correct sid: '%s'\n", matches[SID_INDEX])
	}
	if matches[LEN_INDEX] != "5" {
		t.Fatalf("Did not get correct msg length: '%s'\n", matches[LEN_INDEX])
	}
	checkPayload(cr, []byte("hello\r\n"), t)
}

func TestClientSimplePubSubWithReply(t *testing.T) {
	_, c, cr := setupClient()

	// SUB/PUB
	go c.parse([]byte("SUB foo 1\r\nPUB foo bar 5\r\nhello\r\nPING\r\n"))
	l, err := cr.ReadString('\n')
	if err != nil {
		t.Fatalf("Error receiving msg from server: %v\n", err)
	}
	matches := msgPat.FindAllStringSubmatch(l, -1)[0]
	if len(matches) != 6 {
		t.Fatalf("Did not get correct # matches: %d vs %d\n", len(matches), 6)
	}
	if matches[SUB_INDEX] != "foo" {
		t.Fatalf("Did not get correct subject: '%s'\n", matches[SUB_INDEX])
	}
	if matches[SID_INDEX] != "1" {
		t.Fatalf("Did not get correct sid: '%s'\n", matches[SID_INDEX])
	}
	if matches[REPLY_INDEX] != "bar" {
		t.Fatalf("Did not get correct reply subject: '%s'\n", matches[REPLY_INDEX])
	}
	if matches[LEN_INDEX] != "5" {
		t.Fatalf("Did not get correct msg length: '%s'\n", matches[LEN_INDEX])
	}
}

func TestClientNoBodyPubSubWithReply(t *testing.T) {
	_, c, cr := setupClient()

	// SUB/PUB
	go c.parse([]byte("SUB foo 1\r\nPUB foo bar 0\r\n\r\nPING\r\n"))
	l, err := cr.ReadString('\n')
	if err != nil {
		t.Fatalf("Error receiving msg from server: %v\n", err)
	}
	matches := msgPat.FindAllStringSubmatch(l, -1)[0]
	if len(matches) != 6 {
		t.Fatalf("Did not get correct # matches: %d vs %d\n", len(matches), 6)
	}
	if matches[SUB_INDEX] != "foo" {
		t.Fatalf("Did not get correct subject: '%s'\n", matches[SUB_INDEX])
	}
	if matches[SID_INDEX] != "1" {
		t.Fatalf("Did not get correct sid: '%s'\n", matches[SID_INDEX])
	}
	if matches[REPLY_INDEX] != "bar" {
		t.Fatalf("Did not get correct reply subject: '%s'\n", matches[REPLY_INDEX])
	}
	if matches[LEN_INDEX] != "0" {
		t.Fatalf("Did not get correct msg length: '%s'\n", matches[LEN_INDEX])
	}
}

func TestClientPubWithQueueSub(t *testing.T) {
	_, c, cr := setupClient()

	num := 100

	// Queue SUB/PUB
	subs := []byte("SUB foo g1 1\r\nSUB foo g1 2\r\n")
	pubs := []byte("PUB foo bar 5\r\nhello\r\n")
	op := []byte{}
	op = append(op, subs...)
	for i := 0; i < num; i++ {
		op = append(op, pubs...)
	}

	go func() {
		c.parse(op)
		for cp := range c.pcd {
			cp.bw.Flush()
		}
		c.nc.Close()
	}()

	var n1, n2, received int
	for ; ; received++ {
		l, err := cr.ReadString('\n')
		if err != nil {
			break
		}
		matches := msgPat.FindAllStringSubmatch(l, -1)[0]

		// Count which sub
		switch matches[SID_INDEX] {
		case "1":
			n1++
		case "2":
			n2++
		}
		checkPayload(cr, []byte("hello\r\n"), t)
	}
	if received != num {
		t.Fatalf("Received wrong # of msgs: %d vs %d\n", received, num)
	}
	// Threshold for randomness for now
	if n1 < 20 || n2 < 20 {
		t.Fatalf("Received wrong # of msgs per subscriber: %d - %d\n", n1, n2)
	}
}

func TestClientUnSub(t *testing.T) {
	_, c, cr := setupClient()

	num := 1

	// SUB/PUB
	subs := []byte("SUB foo 1\r\nSUB foo 2\r\n")
	unsub := []byte("UNSUB 1\r\n")
	pub := []byte("PUB foo bar 5\r\nhello\r\n")

	op := []byte{}
	op = append(op, subs...)
	op = append(op, unsub...)
	op = append(op, pub...)

	go func() {
		c.parse(op)
		for cp := range c.pcd {
			cp.bw.Flush()
		}
		c.nc.Close()
	}()

	var received int
	for ; ; received++ {
		l, err := cr.ReadString('\n')
		if err != nil {
			break
		}
		matches := msgPat.FindAllStringSubmatch(l, -1)[0]
		if matches[SID_INDEX] != "2" {
			t.Fatalf("Received msg on unsubscribed subscription!\n")
		}
		checkPayload(cr, []byte("hello\r\n"), t)
	}
	if received != num {
		t.Fatalf("Received wrong # of msgs: %d vs %d\n", received, num)
	}
}

func TestClientUnSubMax(t *testing.T) {
	_, c, cr := setupClient()

	num := 10
	exp := 5

	// SUB/PUB
	subs := []byte("SUB foo 1\r\n")
	unsub := []byte("UNSUB 1 5\r\n")
	pub := []byte("PUB foo bar 5\r\nhello\r\n")

	op := []byte{}
	op = append(op, subs...)
	op = append(op, unsub...)
	for i := 0; i < num; i++ {
		op = append(op, pub...)
	}

	go func() {
		c.parse(op)
		for cp := range c.pcd {
			cp.bw.Flush()
		}
		c.nc.Close()
	}()

	var received int
	for ; ; received++ {
		l, err := cr.ReadString('\n')
		if err != nil {
			break
		}
		matches := msgPat.FindAllStringSubmatch(l, -1)[0]
		if matches[SID_INDEX] != "1" {
			t.Fatalf("Received msg on unsubscribed subscription!\n")
		}
		checkPayload(cr, []byte("hello\r\n"), t)
	}
	if received != exp {
		t.Fatalf("Received wrong # of msgs: %d vs %d\n", received, exp)
	}
}

func TestClientAutoUnsubExactReceived(t *testing.T) {
	_, c, _ := setupClient()
	defer c.nc.Close()

	// SUB/PUB
	subs := []byte("SUB foo 1\r\n")
	unsub := []byte("UNSUB 1 1\r\n")
	pub := []byte("PUB foo bar 2\r\nok\r\n")

	op := []byte{}
	op = append(op, subs...)
	op = append(op, unsub...)
	op = append(op, pub...)

	ch := make(chan bool)
	go func() {
		c.parse(op)
		ch <- true
	}()

	// Wait for processing
	<-ch

	// We should not have any subscriptions in place here.
	if len(c.subs) != 0 {
		t.Fatalf("Wrong number of subscriptions: expected 0, got %d\n", len(c.subs))
	}
}

func TestClientUnsubAfterAutoUnsub(t *testing.T) {
	_, c, _ := setupClient()
	defer c.nc.Close()

	// SUB/UNSUB/UNSUB
	subs := []byte("SUB foo 1\r\n")
	asub := []byte("UNSUB 1 1\r\n")
	unsub := []byte("UNSUB 1\r\n")

	op := []byte{}
	op = append(op, subs...)
	op = append(op, asub...)
	op = append(op, unsub...)

	ch := make(chan bool)
	go func() {
		c.parse(op)
		ch <- true
	}()

	// Wait for processing
	<-ch

	// We should not have any subscriptions in place here.
	if len(c.subs) != 0 {
		t.Fatalf("Wrong number of subscriptions: expected 0, got %d\n", len(c.subs))
	}
}

func TestClientRemoveSubsOnDisconnect(t *testing.T) {
	s, c, _ := setupClient()
	subs := []byte("SUB foo 1\r\nSUB bar 2\r\n")

	ch := make(chan bool)
	go func() {
		c.parse(subs)
		ch <- true
	}()
	<-ch

	if s.sl.Count() != 2 {
		t.Fatalf("Should have 2 subscriptions, got %d\n", s.sl.Count())
	}
	c.closeConnection()
	if s.sl.Count() != 0 {
		t.Fatalf("Should have no subscriptions after close, got %d\n", s.sl.Count())
	}
}

func TestClientDoesNotAddSubscriptionsWhenConnectionClosed(t *testing.T) {
	s, c, _ := setupClient()
	c.closeConnection()
	subs := []byte("SUB foo 1\r\nSUB bar 2\r\n")

	ch := make(chan bool)
	go func() {
		c.parse(subs)
		ch <- true
	}()
	<-ch

	if s.sl.Count() != 0 {
		t.Fatalf("Should have no subscriptions after close, got %d\n", s.sl.Count())
	}
}

func TestClientMapRemoval(t *testing.T) {
	s, c, _ := setupClient()
	c.nc.Close()
	end := time.Now().Add(1 * time.Second)

	for time.Now().Before(end) {
		s.mu.Lock()
		lsc := len(s.clients)
		s.mu.Unlock()
		if lsc > 0 {
			time.Sleep(5 * time.Millisecond)
		}
	}
	s.mu.Lock()
	lsc := len(s.clients)
	s.mu.Unlock()
	if lsc > 0 {
		t.Fatal("Client still in server map")
	}
}

// TODO: This test timesout for unknown reasons.
//func TestAuthorizationTimeout(t *testing.T) {
//	serverOptions := defaultServerOptions
//	serverOptions.Authorization = "my_token"
//	serverOptions.AuthTimeout = 1
//	s := RunServer(&serverOptions)
//	defer s.Shutdown()
//
//	conn, err := net.Dial("tcp", fmt.Sprintf("%s:%d", serverOptions.Host, serverOptions.Port))
//	if err != nil {
//		t.Fatalf("Error dialing server: %v\n", err)
//	}
//	defer conn.Close()
//	client := bufio.NewReaderSize(conn, maxBufSize)
//	if _, err := client.ReadString('\n'); err != nil {
//		t.Fatalf("Error receiving info from server: %v\n", err)
//	}
//	l, err := client.ReadString('\n')
//	if err != nil {
//		t.Fatalf("Error receiving info from server: %v\n", err)
//	}
//	if !strings.Contains(l, "Authorization Timeout") {
//		t.Fatalf("Authorization Timeout response incorrect: %q\n", l)
//	}
//}

// This is from bug report #18
func TestTwoTokenPubMatchSingleTokenSub(t *testing.T) {
	_, c, cr := setupClient()
	test := []byte("PUB foo.bar 5\r\nhello\r\nSUB foo 1\r\nPING\r\nPUB foo.bar 5\r\nhello\r\nPING\r\n")
	go c.parse(test)
	l, err := cr.ReadString('\n')
	if err != nil {
		t.Fatalf("Error receiving info from server: %v\n", err)
	}
	if !strings.HasPrefix(l, "PONG\r\n") {
		t.Fatalf("PONG response incorrect: %q\n", l)
	}
	// Expect just a pong, no match should exist here..
	l, _ = cr.ReadString('\n')
	if !strings.HasPrefix(l, "PONG\r\n") {
		t.Fatalf("PONG response was expected, got: %q\n", l)
	}
}

func TestUnsubRace(t *testing.T) {
	s := RunServer(nil)
	defer s.Shutdown()

	nc, err := nats.Connect(fmt.Sprintf("nats://%s:%d",
		DefaultOptions.Host,
		DefaultOptions.Port))
	if err != nil {
		t.Fatalf("Error creating client: %v\n", err)
	}
	defer nc.Close()

	ncp, err := nats.Connect(fmt.Sprintf("nats://%s:%d",
		DefaultOptions.Host,
		DefaultOptions.Port))
	if err != nil {
		t.Fatalf("Error creating client: %v\n", err)
	}
	defer ncp.Close()

	sub, _ := nc.Subscribe("foo", func(m *nats.Msg) {
		// Just eat it..
	})

	nc.Flush()

	var wg sync.WaitGroup

	wg.Add(1)

	go func() {
		for i := 0; i < 10000; i++ {
			ncp.Publish("foo", []byte("hello"))
		}
		wg.Done()
	}()

	time.Sleep(5 * time.Millisecond)

	sub.Unsubscribe()

	wg.Wait()
}

func TestTLSCloseClientConnection(t *testing.T) {
	opts, err := ProcessConfigFile("./configs/tls.conf")
	if err != nil {
		t.Fatalf("Error processing config file: %v", err)
	}
	opts.Authorization = ""
	opts.TLSTimeout = 100
	s := RunServer(opts)
	defer s.Shutdown()

	endpoint := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	conn, err := net.DialTimeout("tcp", endpoint, 2*time.Second)
	if err != nil {
		t.Fatalf("Unexpected error on dial: %v", err)
	}
	defer conn.Close()
	br := bufio.NewReaderSize(conn, 100)
	if _, err := br.ReadString('\n'); err != nil {
		t.Fatalf("Unexpected error reading INFO: %v", err)
	}

	tlsConn := tls.Client(conn, &tls.Config{InsecureSkipVerify: true})
	defer tlsConn.Close()
	if err := tlsConn.Handshake(); err != nil {
		t.Fatalf("Unexpected error during handshake: %v", err)
	}
	br = bufio.NewReaderSize(tlsConn, 100)
	connectOp := []byte("CONNECT {\"verbose\":false,\"pedantic\":false,\"tls_required\":true}\r\n")
	if _, err := tlsConn.Write(connectOp); err != nil {
		t.Fatalf("Unexpected error writing CONNECT: %v", err)
	}
	if _, err := tlsConn.Write([]byte("PING\r\n")); err != nil {
		t.Fatalf("Unexpected error writing PING: %v", err)
	}
	if _, err := br.ReadString('\n'); err != nil {
		t.Fatalf("Unexpected error reading PONG: %v", err)
	}

	getClient := func() *client {
		s.mu.Lock()
		defer s.mu.Unlock()
		for _, c := range s.clients {
			return c
		}
		return nil
	}
	// Wait for client to be registered.
	timeout := time.Now().Add(5 * time.Second)
	var cli *client
	for time.Now().Before(timeout) {
		cli = getClient()
		if cli != nil {
			break
		}
	}
	if cli == nil {
		t.Fatal("Did not register client on time")
	}
	// Fill the buffer. Need to send 1 byte at a time so that we timeout here
	// the nc.Close() would block due to a write that can not complete.
	done := false
	for !done {
		cli.nc.SetWriteDeadline(time.Now().Add(time.Second))
		if _, err := cli.nc.Write([]byte("a")); err != nil {
			done = true
		}
		cli.nc.SetWriteDeadline(time.Time{})
	}
	ch := make(chan bool)
	go func() {
		select {
		case <-ch:
			return
		case <-time.After(3 * time.Second):
			fmt.Println("!!!! closeConnection is blocked, test will hang !!!")
			return
		}
	}()
	// Close the client
	cli.closeConnection()
	ch <- true
}

func TestGetCertificateClientName(t *testing.T) {
	// common_name: client_id.client_name
	clientCertificate := `-----BEGIN CERTIFICATE-----
MIIDKzCCAhOgAwIBAgIQXiPhocaHSsF6En2BeVM9ajANBgkqhkiG9w0BAQsFADAm
MQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoTDUNsb3VkIEZvdW5kcnkwHhcNMTcwODIx
MjE1MjU2WhcNMTgwODIxMjE1MjU2WjBGMQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoT
DUNsb3VkIEZvdW5kcnkxHjAcBgNVBAMMFWNsaWVudF9pZC5jbGllbnRfbmFtZTCC
ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMV44G/6aRe6gI+DqVAIH0S3
C5TRNYtl/h8HT0EaEnYdcY20MZrusdph7ZdLZ/wHkA++If5mAiP/A1i1uU85Or34
VIY7vRz//ckKzMd4r5Hyh3Ejqi5YzUElzJvac2As79QbgMrqJKt7KYNU3ER/Om2X
iPXPsuFHeTyrWOkZxW+jbNptroATrC8cr7h3yTK2dXD+ta9OrzPsnBUbhDVely6L
QUyNWvPGhQ+Uy3L99kT3AgyIk6kDq6hbHNKAKGA/8yzW6QmCGBsYaifUs93y2Hih
39AAR7J/Z6lwxLrJprPmBfggUdvinkVLOtKDerqg+QDW7+OlxyMbRLKMytvkQB0C
AwEAAaM1MDMwDgYDVR0PAQH/BAQDAgWgMBMGA1UdJQQMMAoGCCsGAQUFBwMBMAwG
A1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBAIO/7waLbZ9cAje18/f5HTp8
GuLsxZFXyXerOnEzkbSwHBvJ9oEtdLQvgEXo5qfrxP0NrdjjEJsIwDSzstyTpMfW
Yx8dcQR8bCW2y8cZhYP36XjLL5//nMk15TFcG+f6R4OZQWODVHLdzu29ntgsDyjY
D1GoJlm63ESZ4we5Y2nsB7gjYSmadtvF+uHO5D0/5tQZByCKqz23Srh2F7+vQj6v
MRExAXOJTZ6eI+A7ixkD6vCLNeJXrVoigFxbNt6qgpsCHxkoaqkcF6AfBHIuWNd2
oPwekVPuv6H1Lc1Wq0xUpb6nwxZsqYxtT0p0Lxx81QFfFx3tpH/2SPUtL0JQSbw=
-----END CERTIFICATE-----`

	cpb, _ := pem.Decode([]byte(clientCertificate))
	crt, _ := x509.ParseCertificate(cpb.Bytes)

	client := client{clientCertificate: crt}

	expectedCertificateClientName := "client_name"
	expectedCertificateClientID := "client_id"

	actualCertificateClientName, actualCertificateClientID, _ := client.GetCertificateClientNameAndID()

	if actualCertificateClientName != expectedCertificateClientName {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientName, expectedCertificateClientName)
	}

	if actualCertificateClientID != expectedCertificateClientID {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientID, expectedCertificateClientID)
	}
}

func TestGetCertificateClientNameNoCertificate(t *testing.T) {
	client := client{clientCertificate: nil}

	_, _, err := client.GetCertificateClientNameAndID()
	if err == nil {
		t.Fatalf("Expected error, got nil")
	}

	expectedErrorMessage := "Client does not have a certificate"
	if err.Error() != expectedErrorMessage {
		stackFatalf(t, "Expected %s to equal %s", err.Error(), expectedErrorMessage)
	}
}

func TestGetCertificateClientNameNoCommonName(t *testing.T) {
	clientCertificate := `-----BEGIN CERTIFICATE-----
MIIDDDCCAfSgAwIBAgIRANNAvhLbz8ppp1dhqUXPufkwDQYJKoZIhvcNAQELBQAw
JjEMMAoGA1UEBhMDVVNBMRYwFAYDVQQKEw1DbG91ZCBGb3VuZHJ5MB4XDTE3MDgx
NDIwMzM1N1oXDTE4MDgxNDIwMzM1N1owJjEMMAoGA1UEBhMDVVNBMRYwFAYDVQQK
Ew1DbG91ZCBGb3VuZHJ5MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
689hB+0cxRlio3ZcaUxAkNSjmBKwfjI379FSyux30GaF9feV+ZgWSNOqKoY534DP
VmMAuoHl/12BwUi5O3RtztQLHLBNtXsAgrn21kkgjvZo29/I24LrB/Xw0lSm2V+O
klZz6LhVIpjAKWh6z4bE3QCW95Bipj9aos6BU3YDmducOSN23JrY9pyl0epoDahl
4JKB8npQZ0MOcXYxAjIAX7ea8jphPuem65fpvlBzkjfmryXpclsvg2lxc/SfHCks
R8dO0ttoswv7YgChqUvGxyZ6NOz3EWmHOVojGr6Mu1vF0egb+S96ro7icAVxDJhV
9xj5G/l+PLd9IYWMflNsGwIDAQABozUwMzAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0l
BAwwCgYIKwYBBQUHAwIwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAQEA
fCFABI++voIBTQSfdELchXm6FiIBsTIFbFFsiqfRN5di0i9pMq6L/ekYlqXSoe7Z
5uHMmf7jcNdYxgLuS6A4xEWGpVsbMSt80B6/UTIi7UtTxSRv5toqCB6WN3Rh4iRd
4m/sKwXnuChjz6GTdB30YoKUQX/b+rDKCbLQ7zJWPI+3UJSmrgnTp0r1jO1io4pn
05mmDisyNv7jTlqSo143QEqWSeb8FTTqA9zV+84m+1pkbkQDE4pN41eUdedrprTq
ndmdXI8j8ycbjIqrsCnO1m0D4BAhYOPQVry1OR13LpyZZIf8jkfSSSVrzRpxUQab
IwKkI6wszdjZ9f6pPUbI9w==
-----END CERTIFICATE-----`

	cpb, _ := pem.Decode([]byte(clientCertificate))
	crt, _ := x509.ParseCertificate(cpb.Bytes)

	client := client{clientCertificate: crt}

	expectedCertificateClientName := ""
	expectedCertificateClientID := ""

	actualCertificateClientName, actualCertificateClientID, _ := client.GetCertificateClientNameAndID()

	if actualCertificateClientName != expectedCertificateClientName {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientName, expectedCertificateClientName)
	}

	if actualCertificateClientID != expectedCertificateClientID {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientID, expectedCertificateClientID)
	}
}

func TestGetCertificateClientNameCommonNameNoDots(t *testing.T) {
	// common_name: client_name
	clientCertificate := `-----BEGIN CERTIFICATE-----
MIIDITCCAgmgAwIBAgIQYe/4XOJqG3r27dxad5ymNDANBgkqhkiG9w0BAQsFADAm
MQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoTDUNsb3VkIEZvdW5kcnkwHhcNMTcwODIx
MjEzNzAxWhcNMTgwODIxMjEzNzAxWjA8MQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoT
DUNsb3VkIEZvdW5kcnkxFDASBgNVBAMMC2NsaWVudF9uYW1lMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyEq1CMddSUXa/d6aIFh1WAsY+5zXs1QFbNw6
0YlVc57oq8guS40FkAev4fK+8P6DAk+KreH3HV7OAOItI62/zl2jJ9PETMHqIVir
YcxP+llzBU62w+/leqvdjzEnJSFDT7sytZjgrGYQb++ozvLXQQqtrL/BKjKVF+TW
r+3l1gZZ5DYG+Pltdsy9jO1HKMIxxI6QkF1Gtswr56Kw6mskG2n4xJ8Q++kLRRdw
CxsQFvGuTytFn/JaAvIuWNtfKeZOVeDUIY/lf5GbM9PM4oUsYrvgMDn3vCWMAiAm
1vA+K4mNwj8jIgRxDO+hTK0IfraqcAD0dx8hSb6BAV0GAgRbUQIDAQABozUwMzAO
BgNVHQ8BAf8EBAMCBaAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDAYDVR0TAQH/BAIw
ADANBgkqhkiG9w0BAQsFAAOCAQEAeZx000v6/2WFFcfYFeMCf0IoOxsVcxnkPcYk
+m1ARcuBnxpm/bTOy6OFf022XVeSC79Zwul5wGQLW0qopv8+HtZx/F+4gC63Ff+n
MJBTL4XmdD6otiLNeRRT5cdTsRcg0sp8LtsRQLpwGKJx1/3/ZbVpKweCjx+hAy3I
lKNmm/hNhFvcj1lVimymPN2xjUTU6iReQqIgnfKdj1zfZH75N28OBBYiwbvPrqmH
64samF+X9Yz7BuGxs0yNtkLMOjHMkKRQJr9+iL7MYMQ+NFu7MFCIynN6OfFpl3KN
pzsSv0xSoKW7MrAeszxJwkNuhd7789VzCgOX1/OhNo87qMH6dw==
-----END CERTIFICATE-----`

	cpb, _ := pem.Decode([]byte(clientCertificate))
	crt, _ := x509.ParseCertificate(cpb.Bytes)

	client := client{clientCertificate: crt}

	_, _, err := client.GetCertificateClientNameAndID()

	if err == nil {
		t.Fatalf("Expected error but none received.")
	}

	expectedErrorMessage := "Clients must present both NAME and ID. `<client_id>.<client_name>`"
	if err.Error() != expectedErrorMessage {
		stackFatalf(t, "Expected %s to equal %s", err.Error(), expectedErrorMessage)
	}
}

func TestGetCertificateClientNameCommonNameOneDot(t *testing.T) {
	// common_name : .client_name
	clientCertificate := `-----BEGIN CERTIFICATE-----
MIIDIjCCAgqgAwIBAgIQScXZ5OE8HWrfMJ7QZS7WHzANBgkqhkiG9w0BAQsFADAm
MQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoTDUNsb3VkIEZvdW5kcnkwHhcNMTcwODIx
MjE1MzQ2WhcNMTgwODIxMjE1MzQ2WjA9MQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoT
DUNsb3VkIEZvdW5kcnkxFTATBgNVBAMMDC5jbGllbnRfbmFtZTCCASIwDQYJKoZI
hvcNAQEBBQADggEPADCCAQoCggEBAKzA6p6Sgq4HKrnJ3xZu9GrazMQ+hNgpXH2E
c/BlGUdHAWrqvI6CTixe1OBvB5VE53E1NIsqYRfToRHeVbk0wE2qTO7NQQz0Qzvt
E5ZBTFA6COnKu8AdnUjb7o87bLloyw6CAclAcBa9p8y0/Kly/Egc6tfLplB34krK
OnIrGMUqnGO/Rh6tZ59Fa5QhEfXH8gWIL8i/A+4y7AIRxc+QQThnwmLmbv/vibvH
G7ccUEmDNueMruvpbF1dnFYcTWwvbTilhgzfBnAr9b9nFBOFMCuK6gWSjIVMb4QB
FED+KjvJdqBIr1tP/2fWxEPBLMEmWBd7pPowDDEqfZ7Vz0CFz1MCAwEAAaM1MDMw
DgYDVR0PAQH/BAQDAgWgMBMGA1UdJQQMMAoGCCsGAQUFBwMBMAwGA1UdEwEB/wQC
MAAwDQYJKoZIhvcNAQELBQADggEBAM9mJuSWxnbJp1Y1StlsFzDkDXifSU1pMt4C
WidRTSLVKbXTtqIosdBFSXrPypBKAJuBB0LuBOAG3ZpwkYxDklrSl3nd/u0zD8J4
7PLhmD6xELCsrR/FqvjxslDsX1QzC/2NNQVShdlFyGcE/OD+SJByktnf+032Y/Fw
WF69fUgTlvuynPIRLuaVf8K9P0dWHT8o08QstjBR3NhByX9oT9k94jzPjc1voxwE
uWLWGrXfwZ8y42A4ZaKhR7yvugjXNTbZ7thytZUly4jHFDanX4zHS5vXX+wybGXO
IQ3pchjIInFZ5hmwEegY8RrRpwksQjR6uxnZg/dKii0UarZt3HI=
-----END CERTIFICATE-----`

	cpb, _ := pem.Decode([]byte(clientCertificate))
	crt, _ := x509.ParseCertificate(cpb.Bytes)

	client := client{clientCertificate: crt}

	expectedCertificateClientName := "client_name"
	expectedCertificateClientID := ""

	actualCertificateClientName, actualCertificateClientID, _ := client.GetCertificateClientNameAndID()

	if actualCertificateClientName != expectedCertificateClientName {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientName, expectedCertificateClientName)
	}

	if actualCertificateClientID != expectedCertificateClientID {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientID, expectedCertificateClientID)
	}
}

func TestGetCertificateClientNameCommonNameMultiDots(t *testing.T) {
	// common_name : client_id.client_name_part1.client_name_part2
	clientCertificate := `-----BEGIN CERTIFICATE-----
MIIDQzCCAiugAwIBAgIQJ7wmjjknrx/aEWh9L8vpFDANBgkqhkiG9w0BAQsFADAm
MQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoTDUNsb3VkIEZvdW5kcnkwHhcNMTcwODIx
MjEyMzIxWhcNMTgwODIxMjEyMzIxWjBeMQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoT
DUNsb3VkIEZvdW5kcnkxNjA0BgNVBAMMLWNsaWVudF9pZC5jbGllbnRfbmFtZV9w
YXJ0MS5jbGllbnRfbmFtZV9wYXJ0MjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
AQoCggEBALWGRruxiv8vNaV+LkpXjoeyKovOOj4/DSXFxcRJjOMWKcDWkC5c31sW
qtxDecLPDI9OnNSGbr7r2GSCGPvMoEV/Ut9J1PfbzNSB29eKET1pqrG3XZhr2/rt
HX5CiE1PdEmeHW+CtC2ioKa4gO2xHfnjGafRUSzoq+R/ubFalDXpXkR49zqsO4bj
WqY8qugmQBf6ZQNf688E9EBDFcCAbCKm0G1Zn4qlc8a7GJ7Lcx0fZQRdsAAZTJLx
3BvLJeIWg+g1fnLYCGrLTydpfowzMcSyIcoQi8SgrKHENOtpfN0iK8rCSJM6f1cH
bA1nBv6//KovPeRmi4nPPDBwGN6Cy4ECAwEAAaM1MDMwDgYDVR0PAQH/BAQDAgWg
MBMGA1UdJQQMMAoGCCsGAQUFBwMBMAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEL
BQADggEBADB/JOoAxXrwgfgPBIbPe023j5w8NtZa4ODe5WkjYhcFWMv38U4jMv9b
YDqClDCnhiPwx02GaY/T6B3GtS5B6teT1wh7EXojMj5ogu4cmKweG2u3gXDB5bDY
YyzKi/+Gqmha+j7CM1lqnQyhpzVzVgmFDsQv3ca0YUH6rYeIOTgCtzHec9MFEGwm
Ad5nPtCy48Wl9E0FZ5owGkDRd4I7v6OklhqwzStF2b/X7VGZwx51FuCttfYM7Z65
FrhOS0CwXFPkqqvcH29mxMQnFXb2+4ofEjcNGZ6fplTCpXYtnyyvsKY8TasepSXF
edEBThwyxIVYZxo3V+r3Pu27RPVDRGE=
-----END CERTIFICATE-----`

	cpb, _ := pem.Decode([]byte(clientCertificate))
	crt, _ := x509.ParseCertificate(cpb.Bytes)

	client := client{clientCertificate: crt}

	expectedCertificateClientName := "client_name_part1.client_name_part2"
	expectedCertificateClientID := "client_id"

	actualCertificateClientName, actualCertificateClientID, _ := client.GetCertificateClientNameAndID()

	if actualCertificateClientName != expectedCertificateClientName {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientName, expectedCertificateClientName)
	}

	if actualCertificateClientID != expectedCertificateClientID {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientID, expectedCertificateClientID)
	}
}

func TestGetCertificateClientNameCommonNameMultiConsecutiveDots(t *testing.T) {
	// common_name : ..client_name
	clientCertificate := `-----BEGIN CERTIFICATE-----
MIIDJDCCAgygAwIBAgIRAPfoeNhuIwijDh9yFnPlG4MwDQYJKoZIhvcNAQELBQAw
JjEMMAoGA1UEBhMDVVNBMRYwFAYDVQQKEw1DbG91ZCBGb3VuZHJ5MB4XDTE3MDgy
MTIxNTI1NloXDTE4MDgyMTIxNTI1NlowPjEMMAoGA1UEBhMDVVNBMRYwFAYDVQQK
Ew1DbG91ZCBGb3VuZHJ5MRYwFAYDVQQDDA0uLmNsaWVudF9uYW1lMIIBIjANBgkq
hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwYbDn9vUnHnrx9LiC2DzXnLI5G0XY4o9
sEfhmFdCiKvbpSw50CBUSxuIn8PrbcCalJefVBmYWQyPj2pUDYe6kUCxJyRRjsrW
rzVfShwIVkr9CPrdWldqxtqjm3iPeYfSV3xqrmbB43mzDRv/xyYBbKdtdiUJCA9c
MrbfwlPD4+hIC3IUpt8gOhaLmBgy4zdYrgUt/a7J7obtjQzQHcv71djJ24g9gyZU
0Y8mYtcEpH0HaMaShHbmBWHLrmx8GB5d+RsCt5wbu2pvBbXS6itIUO1smCgYTWEi
KqycEup4YWUI4l+GbI02AJH4/nFLtwIemgQQHjCm7ixpIFbaPLXluwIDAQABozUw
MzAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDAYDVR0TAQH/
BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAQqK1I+bLfwN5RCDmq4/C51iNapVn31UI
0UBMmhvo51KLMn62RObzJIwAmqiZNUCfuMWZ2OzpGVH4Ohezq5FWwTotQqxNDlz1
0bkuGMbS5YCSCEJuAwb2XVESAj1xjM+cejsmMn/skWAgrtdkXgThiMqpgd6mrnAs
yu1CVJ6Y5Q1sLXntw7KCnB47UMGVPFI/cjQhoqvjKTDN1piJLpwekbi7zry/rIr6
39/CS822eb6thGB4tffWd/nku+VJjhmsIXMeqFsCzycvCapI8Nb94l8xdctwoRti
iM6qM8mUu4Rac0N0Q2bSH7c9s8Xr9XcBx9ogzOaf+gVkL5PyDjkffw==
-----END CERTIFICATE-----`

	cpb, _ := pem.Decode([]byte(clientCertificate))
	crt, _ := x509.ParseCertificate(cpb.Bytes)

	client := client{clientCertificate: crt}

	expectedCertificateClientName := ".client_name"
	expectedCertificateClientID := ""

	actualCertificateClientName, actualCertificateClientID, _ := client.GetCertificateClientNameAndID()

	if actualCertificateClientName != expectedCertificateClientName {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientName, expectedCertificateClientName)
	}

	if actualCertificateClientID != expectedCertificateClientID {
		stackFatalf(t, "Expected %s to equal %s", actualCertificateClientID, expectedCertificateClientID)
	}
}