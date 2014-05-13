package syslog_test

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"net"
	"strconv"
	"sync"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "bosh/logger"
	. "bosh/syslog"
)

var _ = Describe("Server", func() {
	var (
		serverPort uint16
		logger     boshlog.Logger
		server     Server
		msgs       msgCollector
		doneCh     chan struct{}
	)

	grabEphemeralPort := func() uint16 {
		l, err := net.Listen("tcp", ":0")
		Expect(err).ToNot(HaveOccurred())

		defer l.Close()

		_, portStr, err := net.SplitHostPort(l.Addr().String())
		Expect(err).ToNot(HaveOccurred())

		port, err := strconv.Atoi(portStr)
		Expect(err).ToNot(HaveOccurred())

		return uint16(port)
	}

	captureMsgs := func(msg Msg) {
		msgs.Add(msg)
		if len(msgs.Msgs()) == 4 {
			doneCh <- struct{}{}
		}
	}

	captureOneMsg := func(msg Msg) {
		msgs.Add(msg)
		doneCh <- struct{}{}
	}

	waitToDial := func() (conn net.Conn, err error) {
		for i := 0; i < 10; i++ {
			conn, err = net.Dial("tcp", "127.0.0.1:"+strconv.Itoa(int(serverPort)))
			if err == nil {
				break
			}
			time.Sleep(100 * time.Millisecond)
		}
		return conn, err
	}

	BeforeEach(func() {
		serverPort = grabEphemeralPort()
		logger = boshlog.NewLogger(boshlog.LevelNone)
		server = NewServer(serverPort, logger)
		msgs = msgCollector{}
		doneCh = make(chan struct{})
	})

	It("it calls back on a new syslog message", func() {
		startErrCh := make(chan error)

		go func() {
			defer GinkgoRecover()
			startErrCh <- server.Start(captureMsgs)
		}()

		conn, err := waitToDial()
		Expect(err).ToNot(HaveOccurred())

		fmt.Fprintf(conn, "<38>Jan  1 00:00:00 localhost sshd[22636]: msg1\n")
		fmt.Fprintf(conn, "<38>Jan  1 00:00:00 localhost sshd[22647]: msg2\n")
		fmt.Fprintf(conn, "<38>Jun  7 19:26:05 localhost sshd[23075]: msg3\n")
		fmt.Fprintf(conn, "<38>Jan  1 00:00:00 localhost monkeyd[1337]: msg4\n")

		<-doneCh

		err = server.Stop()
		Expect(err).ToNot(HaveOccurred())

		messages := msgs.Msgs()
		Expect(len(messages)).To(Equal(4))
		Expect(messages[0].Content).To(Equal("msg1"))
		Expect(messages[1].Content).To(Equal("msg2"))
		Expect(messages[2].Content).To(Equal("msg3"))
		Expect(messages[3].Content).To(Equal("msg4"))

		err = <-startErrCh
		Expect(err).To(HaveOccurred())
		Expect(err.(*net.OpError).Op).To(Equal("accept"))

		// Make sure server was stopped
		_, err = net.Dial("tcp", "127.0.0.1:"+strconv.Itoa(int(serverPort)))
		Expect(err).To(HaveOccurred())
		Expect(err.(*net.OpError).Op).To(Equal("dial"))
	})

	It("it can accept multiple connections at once", func() {
		go server.Start(captureMsgs)

		conn1, err := waitToDial()
		Expect(err).ToNot(HaveOccurred())

		conn2, err := waitToDial()
		Expect(err).ToNot(HaveOccurred())

		fmt.Fprintf(conn1, "<38>Jan  1 00:00:00 localhost sshd[22636]: msg1\n")
		fmt.Fprintf(conn2, "<38>Jan  1 00:00:00 localhost sshd[22647]: msg2\n")
		fmt.Fprintf(conn1, "<38>Jan  1 00:00:00 localhost sshd[22636]: msg3\n")
		fmt.Fprintf(conn2, "<38>Jan  1 00:00:00 localhost sshd[22647]: msg4\n")

		<-doneCh

		err = server.Stop()
		Expect(err).ToNot(HaveOccurred())

		contents := []string{}
		for _, m := range msgs.Msgs() {
			contents = append(contents, m.Content)
		}

		Expect(len(contents)).To(Equal(4))
		Expect(contents).To(ContainElement("msg1"))
		Expect(contents).To(ContainElement("msg2"))
		Expect(contents).To(ContainElement("msg3"))
		Expect(contents).To(ContainElement("msg4"))
	})

	It("returns error if server fails to listen", func() {
		server := NewServer(10, logger) // lower port; should fail unless running as root
		err := server.Start(nil)
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("Listening on port 10"))
	})

	It("logs parsing error to error log if parsing syslog message fails", func() {
		outBuf := bytes.NewBufferString("")
		errBuf := NewLockedWriter(bytes.NewBufferString(""))
		logger := boshlog.NewWriterLogger(boshlog.LevelDebug, outBuf, errBuf)
		server = NewServer(serverPort, logger)

		go server.Start(captureOneMsg)

		conn, err := waitToDial()
		Expect(err).ToNot(HaveOccurred())

		fmt.Fprintf(conn, "<38>Jan  1 00:00:00 localhost sshd[22636]: msg1\n")
		fmt.Fprintf(conn, "invalid-syslog-format\n")
		fmt.Fprintf(conn, "<38>Jan  1 00:00:00 localhost sshd[22636]: msg2\n")

		<-doneCh

		err = server.Stop()
		Expect(err).ToNot(HaveOccurred())

		Expect(string(errBuf.Bytes())).To(
			ContainSubstring("Failed to parse syslog message"))

		// Make sure that subsequent messages are still interpreted
		messages := msgs.Msgs()
		Expect(len(messages)).To(Equal(2))
		Expect(messages[0].Content).To(Equal("msg1"))
		Expect(messages[1].Content).To(Equal("msg2"))
	})

	It("logs parsing error to error log if parsing fails while scanning for next message", func() {
		writeCh := make(chan struct{}, 1)

		outBuf := bytes.NewBufferString("")
		errBuf := NewNotifyingWriter(NewLockedWriter(bytes.NewBufferString("")), writeCh)
		logger := boshlog.NewWriterLogger(boshlog.LevelDebug, outBuf, errBuf)
		server = NewServer(serverPort, logger)

		go server.Start(nil)

		conn, err := waitToDial()
		Expect(err).ToNot(HaveOccurred())

		// Make large input to overflow scanner
		chars := make([]byte, bufio.MaxScanTokenSize)
		for i := range chars {
			chars[i] = 'A'
		}

		fmt.Fprintf(conn, string(chars))

		<-writeCh

		err = server.Stop()
		Expect(err).ToNot(HaveOccurred())

		// Make sure connection is closed
		for i := 0; i < 20; i++ {
			_, err = conn.Write([]byte("err"))
			if err != nil {
				break
			}
			time.Sleep(100 * time.Millisecond)
		}
		Expect(err).To(HaveOccurred())
		Expect(err.(*net.OpError).Op).To(Equal("write"))

		Expect(string(errBuf.Bytes())).To(
			ContainSubstring("Scanner error while parsing syslog message"))
	})
})

type writableBuffer interface {
	io.Writer
	Bytes() []byte
}

type lockedWriter struct {
	writableBuffer
	lock sync.Mutex
}

func NewLockedWriter(writer writableBuffer) *lockedWriter {
	return &lockedWriter{writableBuffer: writer}
}

func (buf *lockedWriter) Write(b []byte) (int, error) {
	buf.lock.Lock()
	defer buf.lock.Unlock()
	return buf.writableBuffer.Write(b)
}

func (buf *lockedWriter) Bytes() []byte {
	buf.lock.Lock()
	defer buf.lock.Unlock()
	return buf.writableBuffer.Bytes()
}

type notifyingWriter struct {
	writableBuffer
	wroteCh chan struct{}
}

func NewNotifyingWriter(writer writableBuffer, wroteCh chan struct{}) *notifyingWriter {
	return &notifyingWriter{writableBuffer: writer, wroteCh: wroteCh}
}

func (buf *notifyingWriter) Write(b []byte) (int, error) {
	defer func() { buf.wroteCh <- struct{}{} }()
	return buf.writableBuffer.Write(b)
}

type msgCollector struct {
	msgs []Msg
	lock sync.Mutex
}

func (mc *msgCollector) Add(msg Msg) {
	mc.lock.Lock()
	defer mc.lock.Unlock()

	mc.msgs = append(mc.msgs, msg)
}

func (mc *msgCollector) Msgs() []Msg {
	mc.lock.Lock()
	defer mc.lock.Unlock()

	copiedMsgs := make([]Msg, len(mc.msgs))
	copy(copiedMsgs, mc.msgs)
	return copiedMsgs
}
