package server

import (
	"bytes"
	"github.com/nats-io/gnatsd/server/fakes"
	"io"
	"testing"
)

func TestPeekableConn_Read(t *testing.T) {
	fakeConnBytes := []byte{10, 11, 12}
	fakeConn := &netfakes.FakeConn{}
	fakeConn.ReadStub = fakeReadImpl(fakeConnBytes,3)

	peekConn := NewPeekableConn(fakeConn)

	actualBytes := make([]byte, 3)
	peekConn.Read(actualBytes)
	peekConn.Read(actualBytes)

	if fakeConn.ReadCallCount() != 2 {
		t.Fatalf("Read call count expected: 1, actual:%v", fakeConn.ReadCallCount())
	}

	if bytes.Compare(fakeConnBytes, actualBytes) != 0 {
		t.Fatalf("Expected actualBytes read to be :%v but they were :%v",
			fakeConnBytes, actualBytes)
	}
}

// PeekFirst when connection only contains exact number of bytes requested
func TestPeekableConn_PeekFirst(t *testing.T) {
	bytesToPeek := 7

	fakeConn := &netfakes.FakeConn{}
	fakeConnBytes := []byte{10, 11, 12, 13, 14, 15, 16}
	fakeConn.ReadStub = fakeReadImpl(fakeConnBytes,2)

	peekConn := NewPeekableConn(fakeConn)
	result, err := peekConn.PeekFirst(bytesToPeek)

	if bytes.Compare(result, fakeConnBytes[:bytesToPeek]) != 0 {
		t.Fatalf("Error: %v", result)
	}

	if err != nil {
		t.Fatalf("Expected err to be nil but was : %v", err)
	}
}

// PeekFirst when connection is buffering so multiple Reads are required to obtain number of desired bytes
func TestPeekableConn_PeekFirst_MultipleReads(t *testing.T) {
	bytesToPeek := 7

	fakeConn := &netfakes.FakeConn{}
	fakeConnBytes := []byte{10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}


	fakeConn.ReadStub = fakeReadImpl(fakeConnBytes,2)

	peekConn := NewPeekableConn(fakeConn)
	result, err := peekConn.PeekFirst(bytesToPeek)

	if bytes.Compare(result, fakeConnBytes[:bytesToPeek]) != 0 {
		t.Fatalf("Expected result to be: %v but was : %v", fakeConnBytes[:bytesToPeek], result)
	}

	if err != nil {
		t.Fatalf("Expected err to be nil but was : %v", err)
	}
}

// PeekFirst when connection is does not have number of desired bytes
func TestPeekableConn_PeekFirst_NotEnoughBytes(t *testing.T) {
	bytesToPeek := 10

	fakeConn := &netfakes.FakeConn{}
	fakeConnBytes := []byte{10, 11, 12}

	fakeConn.ReadStub = fakeReadImpl(fakeConnBytes,4)

	peekConn := NewPeekableConn(fakeConn)

	_, err := peekConn.PeekFirst(bytesToPeek)
	if err == nil {
		t.Fatal("Expected err but no err was returned.")
	}
}

// Integration of PeekFirst & then Read, expecting Read to return the entire byte stream transparently to the consumer
func TestPeekableConn_PeekFirst_Then_Read(t *testing.T) {
	bytesToPeek := 5

	fakeConn := &netfakes.FakeConn{}

	fakeConnBytes := []byte{10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20}

	fakeConn.ReadStub = fakeReadImpl(fakeConnBytes,4)

	peekConn := NewPeekableConn(fakeConn)

	_, err := peekConn.PeekFirst(bytesToPeek)
	if err != nil {
		t.Fatal("Expected err to be nil")
	}

	actualReadBytes := make([]byte, len(fakeConnBytes))

	actualBytesReadCount1, err := peekConn.Read(actualReadBytes)
	assertErrorIsNil(t, err)

	actualBytesReadCount2, err := peekConn.Read(actualReadBytes[actualBytesReadCount1:])
	assertErrorIsNil(t, err)

	actualBytesReadCount3, err := peekConn.Read(actualReadBytes[actualBytesReadCount1+actualBytesReadCount2:])
	if err == nil {
		t.Fatalf("Expected err to NOT be nil but was : %v", err)
	}

	if bytes.Compare(actualReadBytes, fakeConnBytes) != 0 {
		t.Fatalf("Expected result to be: %v but was : %v", fakeConnBytes, actualReadBytes)
	}

	if actualBytesReadCount3 != 0 {
		t.Fatalf("Expected result to be: %v but was : %v", 0, actualBytesReadCount3)
	}

}

func assertErrorIsNil(t *testing.T, err error) {
	if err != nil {
		t.Fatalf("Expected err to be nil but was : %v", err)
	}
}

func fakeReadImpl(data []byte, maxBytesToReadPerOp int ) (func(b []byte) (n int, err error)){
	fakeReadCursor := 0
	return func(b []byte) (n int, err error) {

		if fakeReadCursor >= len(data) {
			return 0, io.EOF
		}

		bytesCopied := 0
		if fakeReadCursor+maxBytesToReadPerOp > len(data) {
			bytesCopied = copy(b, data[fakeReadCursor:])
		} else {
			bytesCopied = copy(b, data[fakeReadCursor:fakeReadCursor+maxBytesToReadPerOp])
		}

		fakeReadCursor += bytesCopied

		return bytesCopied, nil
	}
}

