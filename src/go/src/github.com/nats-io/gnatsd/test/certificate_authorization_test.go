package test

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"strings"
	"testing"

	"time"

	"regexp"

	"github.com/nats-io/go-nats"
)

func TestNonTLSConnectionsWithMutualTLSServer(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization_legacy_auth_enabled.conf")
	defer srv.Shutdown()

	clientA := createClientConn(t, "localhost", opts.Port)
	defer clientA.Close()

	sendA, expectA := setupConnWithAuth(t, clientA, opts.Username, opts.Password)
	sendA("SUB foo 22\r\n")
	sendA("PING\r\n")
	expectA(pongRe)

	if err := checkExpectedSubs(1, srv); err != nil {
		t.Fatalf("%v", err)
	}

	clientB := createClientConn(t, "localhost", opts.Port)
	defer clientB.Close()

	sendB, expectB := setupConnWithAuth(t, clientB, opts.Username, opts.Password)
	sendB("PUB foo 2\r\nok\r\n")
	sendB("PING\r\n")
	expectB(pongRe)

	expectMsgs := expectMsgsCommand(t, expectA)

	matches := expectMsgs(1)
	checkMsg(t, matches[0], "foo", "22", "", "2", "ok")
}

func TestNonTLSConnectionsWithMutualTLSServer_AllowLegacyClientsDisabled(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization.conf")
	defer srv.Shutdown()

	clientA := createClientConn(t, "localhost", opts.Port)
	defer clientA.Close()

	_, expectA := setupConnWithAuth(t, clientA, "some_user", "some_pass")
	expectA(regexp.MustCompile(`\x15\x03\x01\x00\x02\x02\x16`))
}

func TestNonTLSConnectionsWithMutualTLSServer_AllowLegacyClientsDisabled_EmptyUser(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization.conf")
	defer srv.Shutdown()

	clientA := createClientConn(t, "localhost", opts.Port)
	defer clientA.Close()

	_, expectA := setupConnWithAuth(t, clientA, "", "")
	expectA(regexp.MustCompile(`\x15\x03\x01\x00\x02\x02\x16`))
}

func TestNonTLSConnectionsWithMutualTLSServer_AllowLegacyClientsEnabled(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization_legacy_auth_enabled.conf")
	defer srv.Shutdown()

	clientA := createClientConn(t, "localhost", 4222)

	sendA, expectA := setupConnWithAuth(t, clientA, opts.Username, opts.Password)
	sendA("SUB foo 22\r\n")
	sendA("PING\r\n")
	expectA(pongRe)

	if err := checkExpectedSubs(1, srv); err != nil {
		t.Fatalf("%v", err)
	}

	clientB := createClientConn(t, "localhost", 4222)

	sendB, expectB := setupConnWithAuth(t, clientB, opts.Username, opts.Password)
	sendB("PUB foo 2\r\nok\r\n")
	sendB("PING\r\n")
	expectB(pongRe)

	expectMsgs := expectMsgsCommand(t, expectA)

	matches := expectMsgs(1)
	checkMsg(t, matches[0], "foo", "22", "", "2", "ok")
}

func TestNonTLSConnectionsWithMutualTLSServer_AllowLegacyClientsEnabled_UnauthenticatedUser(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization_legacy_auth_enabled.conf")
	defer srv.Shutdown()

	clientA := createClientConn(t, "localhost", opts.Port)
	defer clientA.Close()

	_, expectA := setupConnWithAuth(t, clientA, "unauthorized_user", "unauthorized_pass")
	expectA(regexp.MustCompile(`\A-ERR 'Authorization Violation'\r\n`))

	clientB := createClientConn(t, "localhost", opts.Port)
	defer clientB.Close()

	_, expectB := setupConnWithAuth(t, clientB, opts.Username, "incorrect_password")
	expectB(regexp.MustCompile(`\A-ERR 'Authorization Violation'\r\n`))
}

func TestNonTLSConnectionsWithMutualTLSServer_AllowLegacyClientsEnabled_EmptyUser(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization_legacy_auth_enabled.conf")
	defer srv.Shutdown()

	clientA := createClientConn(t, "localhost", opts.Port)
	defer clientA.Close()

	_, expectA := setupConnWithAuth(t, clientA, "", "")
	expectA(regexp.MustCompile(`\A-ERR 'Authorization Violation'\r\n`))
}

//========================================================================
//========================================================================
// TLS Clients

func TestTLSConnections_CertificateAuthorizationEnable_CertificateCommonNameStartWithDot(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization.conf")
	defer srv.Shutdown()

	endpoint := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	nurl := fmt.Sprintf("tls://%s/", endpoint)

	// Load client certificate to successfully connect.
	certFile := "./configs/certs/certificate_authorization/client-id-only.pem"
	keyFile := "./configs/certs/certificate_authorization/client-id-only.key"
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		t.Fatalf("error parsing X509 certificate/key pair: %v", err)
	}

	// Load in root CA for server verification
	rootPEM, err := ioutil.ReadFile("./configs/certs/certificate_authorization/ca.pem")
	if err != nil || rootPEM == nil {
		t.Fatalf("failed to read root certificate")
	}
	pool := x509.NewCertPool()
	ok := pool.AppendCertsFromPEM([]byte(rootPEM))
	if !ok {
		t.Fatalf("failed to parse root certificate")
	}

	// Now do more advanced checking, verifying servername and using rootCA.
	config := &tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   opts.Host,
		RootCAs:      pool,
		MinVersion:   tls.VersionTLS12,
	}

	nc, err := nats.Connect(nurl, nats.Secure(config))

	if err == nil {
		nc.Close()
		t.Fatalf("Expected error, but none received.")
	}

	expectedErrorMessage := "nats: authorization violation"
	if !strings.Contains(err.Error(), expectedErrorMessage) {
		stackFatalf(t, "Expected '%s' to contain '%s'",  err.Error(), expectedErrorMessage)
	}
}

func TestTLSConnections_CertificateAuthorizationEnable_ClientCertificateNoCommonName(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization.conf")
	defer srv.Shutdown()

	endpoint := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	nurl := fmt.Sprintf("tls://%s:%s@%s/", opts.Username, opts.Password, endpoint)

	// Load client certificate to successfully connect.
	certFile := "./configs/certs/certificate_authorization/client-no-common-name.pem"
	keyFile := "./configs/certs/certificate_authorization/client-no-common-name.key"
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		t.Fatalf("error parsing X509 certificate/key pair: %v", err)
	}

	// Load in root CA for server verification
	rootPEM, err := ioutil.ReadFile("./configs/certs/certificate_authorization/ca.pem")
	if err != nil || rootPEM == nil {
		t.Fatalf("failed to read root certificate")
	}
	pool := x509.NewCertPool()
	ok := pool.AppendCertsFromPEM([]byte(rootPEM))
	if !ok {
		t.Fatalf("failed to parse root certificate")
	}

	// Now do more advanced checking, verifying servername and using rootCA.
	config := &tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   opts.Host,
		RootCAs:      pool,
		MinVersion:   tls.VersionTLS12,
	}

	nc, err := nats.Connect(nurl, nats.Secure(config))

	if err == nil {
		nc.Close()
		t.Fatalf("Expected error, but none received.")
	}

	expectedErrorMessage := "nats: authorization violation"
	if !strings.Contains(err.Error(), expectedErrorMessage) {
		stackFatalf(t, "Expected '%s' to contain '%s'",  err.Error(), expectedErrorMessage)
	}
}

func TestTLSConnections_CertificateAuthorizationEnable_ClientCertificateNonExistentClient(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization.conf")
	defer srv.Shutdown()

	endpoint := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	nurl := fmt.Sprintf("tls://%s:%s@%s/", opts.Username, opts.Password, endpoint)

	// Load client certificate to successfully connect.
	certFile := "./configs/certs/certificate_authorization/non-existent-client.pem"
	keyFile := "./configs/certs/certificate_authorization/non-existent-client.key"
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		t.Fatalf("error parsing X509 certificate/key pair: %v", err)
	}

	// Load in root CA for server verification
	rootPEM, err := ioutil.ReadFile("./configs/certs/certificate_authorization/ca.pem")
	if err != nil || rootPEM == nil {
		t.Fatalf("failed to read root certificate")
	}
	pool := x509.NewCertPool()
	ok := pool.AppendCertsFromPEM([]byte(rootPEM))
	if !ok {
		t.Fatalf("failed to parse root certificate")
	}

	// Now do more advanced checking, verifying servername and using rootCA.
	config := &tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   opts.Host,
		RootCAs:      pool,
		MinVersion:   tls.VersionTLS12,
	}

	nc, err := nats.Connect(nurl, nats.Secure(config))

	if err == nil {
		nc.Close()
		t.Fatalf("Expected error, but none received.")
	}

	expectedErrorMessage := "nats: authorization violation"
	if !strings.Contains(err.Error(), expectedErrorMessage) {
		stackFatalf(t, "Expected '%s' to contain '%s'",  err.Error(), expectedErrorMessage)
	}
}

func TestTLSConnections_CertificateAuthorizationEnable_CertificateClientUnauthorized(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization.conf")
	defer srv.Shutdown()

	endpoint := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	nurl := fmt.Sprintf("tls://%s/", endpoint)

	// Load client certificate to successfully connect.
	certFile := "./configs/certs/certificate_authorization/valid-client.pem"
	keyFile := "./configs/certs/certificate_authorization/valid-client.key"
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		t.Fatalf("error parsing X509 certificate/key pair: %v", err)
	}

	// Load in root CA for server verification
	rootPEM, err := ioutil.ReadFile("./configs/certs/certificate_authorization/ca.pem")
	if err != nil || rootPEM == nil {
		t.Fatalf("failed to read root certificate")
	}
	pool := x509.NewCertPool()
	ok := pool.AppendCertsFromPEM([]byte(rootPEM))
	if !ok {
		t.Fatalf("failed to parse root certificate")
	}

	// Now do more advanced checking, verifying servername and using rootCA.
	config := &tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   opts.Host,
		RootCAs:      pool,
		MinVersion:   tls.VersionTLS12,
	}

	nc, err := nats.Connect(nurl, nats.Secure(config))
	if err != nil {
		t.Fatalf("Got an error on Connect with Secure Options: %+v\n", err)
	}
	defer nc.Close()

	subj := "foo-tls"
	_, err = nc.SubscribeSync(subj)
	nc.Flush()

	err = nc.LastError()
	if err == nil {
		t.Fatalf("An error was expected when subscribing to channel: '%s'", subj)
	}

	expectedSuffix := fmt.Sprintf(`permissions violation for subscription to "%s"`, subj)
	if !strings.HasSuffix(err.Error(), expectedSuffix) {
		stackFatalf(t, "Response did not match expected: \n\tReceived:'%q'\n\tExpected to contain:'%s'\n", err.Error(), expectedSuffix)
	}
}

func TestTLSConnections_CertificateAuthorizationEnable_CertificateClientUnauthorized_NoPermissions(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization_no_permissions_defined.conf")
	defer srv.Shutdown()

	endpoint := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	nurl := fmt.Sprintf("tls://%s/", endpoint)

	// Load client certificate to successfully connect.
	certFile := "./configs/certs/certificate_authorization/valid-client.pem"
	keyFile := "./configs/certs/certificate_authorization/valid-client.key"
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		t.Fatalf("error parsing X509 certificate/key pair: %v", err)
	}

	// Load in root CA for server verification
	rootPEM, err := ioutil.ReadFile("./configs/certs/certificate_authorization/ca.pem")
	if err != nil || rootPEM == nil {
		t.Fatalf("failed to read root certificate")
	}
	pool := x509.NewCertPool()
	ok := pool.AppendCertsFromPEM([]byte(rootPEM))
	if !ok {
		t.Fatalf("failed to parse root certificate")
	}

	// Now do more advanced checking, verifying servername and using rootCA.
	config := &tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   opts.Host,
		RootCAs:      pool,
		MinVersion:   tls.VersionTLS12,
	}

	nc, err := nats.Connect(nurl, nats.Secure(config))
	if err != nil {
		t.Fatalf("Got an error on Connect with Secure Options: %+v\n", err)
	}
	defer nc.Close()

	subj := "foo-tls"
	_, err = nc.SubscribeSync(subj)
	nc.Flush()

	err = nc.LastError()
	if err == nil {
		t.Fatalf("An error was expected when subscribing to channel: '%s'", subj)
	}

	expectedSuffix := fmt.Sprintf(`permissions violation for subscription to "%s"`, subj)
	if !strings.HasSuffix(err.Error(), expectedSuffix) {
		stackFatalf(t, "Response did not match expected: \n\tReceived:'%q'\n\tExpected to contain:'%s'\n", err.Error(), expectedSuffix)
	}
}

func TestTLSConnections_CertificateAuthorizationEnable_ClientCertificateAuthenticatedAndAuthorized(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization.conf")
	defer srv.Shutdown()

	endpoint := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	nurl := fmt.Sprintf("tls://%s:%s@%s/", opts.Username, opts.Password, endpoint)

	// Load client certificate to successfully connect.
	certFile := "./configs/certs/certificate_authorization/valid-client.pem"
	keyFile := "./configs/certs/certificate_authorization/valid-client.key"
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		t.Fatalf("error parsing X509 certificate/key pair: %v", err)
	}

	// Load in root CA for server verification
	rootPEM, err := ioutil.ReadFile("./configs/certs/certificate_authorization/ca.pem")
	if err != nil || rootPEM == nil {
		t.Fatalf("failed to read root certificate")
	}
	pool := x509.NewCertPool()
	ok := pool.AppendCertsFromPEM([]byte(rootPEM))
	if !ok {
		t.Fatalf("failed to parse root certificate")
	}

	// Now do more advanced checking, verifying servername and using rootCA.
	config := &tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   opts.Host,
		RootCAs:      pool,
		MinVersion:   tls.VersionTLS12,
	}

	nc, err := nats.Connect(nurl, nats.Secure(config))
	if err != nil {
		t.Fatalf("Got an error on Connect with Secure Options: %+v\n", err)
	}
	defer nc.Close()

	subj := "smurf.happy"
	sub, _ := nc.SubscribeSync(subj)

	nc.Publish(subj, []byte("Message is Delivered!"))
	nc.Flush()

	msg, err := sub.NextMsg(2 * time.Second)

	if err != nil {
		t.Fatalf("Expected message to be sent.")
	}

	expectedMessage := "Message is Delivered!"
	if !strings.Contains(string(msg.Data), expectedMessage) {
		stackFatalf(t, "Response did not match expected: \n\tReceived:'%q'\n\tExpected to contain:'%s'\n", string(msg.Data), expectedMessage)
	}
}

func TestTLSConnections_CertificateAuthorizationEnable_CertificateClientUnauthorized_DefaultPermissions(t *testing.T) {
	srv, opts := RunServerWithConfig("./configs/cert_authorization/tlsverify_cert_authorization_default_permssions_defined.conf")
	defer srv.Shutdown()

	endpoint := fmt.Sprintf("%s:%d", opts.Host, opts.Port)
	nurl := fmt.Sprintf("tls://%s:%s@%s/", opts.Username, opts.Password, endpoint)

	// Load client certificate to successfully connect.
	certFile := "./configs/certs/certificate_authorization/valid-client.pem"
	keyFile := "./configs/certs/certificate_authorization/valid-client.key"
	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		t.Fatalf("error parsing X509 certificate/key pair: %v", err)
	}

	// Load in root CA for server verification
	rootPEM, err := ioutil.ReadFile("./configs/certs/certificate_authorization/ca.pem")
	if err != nil || rootPEM == nil {
		t.Fatalf("failed to read root certificate")
	}
	pool := x509.NewCertPool()
	ok := pool.AppendCertsFromPEM([]byte(rootPEM))
	if !ok {
		t.Fatalf("failed to parse root certificate")
	}

	// Now do more advanced checking, verifying servername and using rootCA.
	config := &tls.Config{
		Certificates: []tls.Certificate{cert},
		ServerName:   opts.Host,
		RootCAs:      pool,
		MinVersion:   tls.VersionTLS12,
	}

	nc, err := nats.Connect(nurl, nats.Secure(config))
	if err != nil {
		t.Fatalf("Got an error on Connect with Secure Options: %+v\n", err)
	}
	defer nc.Close()

	subj := "gargamel.happy"
	sub, _ := nc.SubscribeSync(subj)

	nc.Publish(subj, []byte("Message is Delivered!"))
	nc.Flush()

	msg, err := sub.NextMsg(2 * time.Second)

	if err != nil {
		t.Fatalf("Expected message to be sent.")
	}

	expectedMessage := "Message is Delivered!"
	if !strings.Contains(string(msg.Data), expectedMessage) {
		stackFatalf(t, "Response did not match expected: \n\tReceived:'%q'\n\tExpected to contain:'%s'\n", string(msg.Data), expectedMessage)
	}
}
