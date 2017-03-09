package server

import (
	"bytes"
	"io"
	"net"
)

type PeekableConn struct {
	net.Conn

	firstBytes *bytes.Buffer
	combined   io.Reader
}

func NewPeekableConn(conn net.Conn) *PeekableConn {
	firstBytes := new(bytes.Buffer)
	return &PeekableConn{conn, firstBytes, io.MultiReader(firstBytes, conn)}
}

func (c *PeekableConn) Read(b []byte) (int, error) {
	return c.combined.Read(b)
}

func (c *PeekableConn) PeekFirst(n int) ([]byte, error) {
	readBytes := make([]byte, n)

	for i := 0; i < n; {
		tmpBytes := make([]byte, n)

		readN, readErr := c.Conn.Read(tmpBytes)
		if readErr != nil && readErr != io.EOF {
			return nil, readErr
		}

		_, err := c.firstBytes.Write(tmpBytes[:readN])
		if err != nil {
			return nil, err
		}

		copy(readBytes[i:], tmpBytes[:minInt(n-i, readN)])
		i += readN

		if readErr == io.EOF {
			if i == n {
				return readBytes, nil
			} else {
				return readBytes, io.EOF
			}
		}
	}

	return readBytes, nil
}

func minInt(a, b int) int {
	if a > b {
		return b
	}
	return a
}
