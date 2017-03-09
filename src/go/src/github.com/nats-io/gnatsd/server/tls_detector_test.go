package server

import "testing"

func TestTLSDetector_Detect(t *testing.T) {
	tls_1_0_record := []byte {22, 3, 1, 0, 0, TLS_CLIENT_HELLO, 0, 0, 0}
	result_1, err_1 := TLSDetector{}.Detect(tls_1_0_record)
	if result_1 == false {
		t.Fatalf("Expected TLSDetector{}.Detect to return true for %d\n", tls_1_0_record)
	}

	if err_1 != nil {
		t.Fatalf("Expected TLSDetector{}.Detect to return nil error for %d\n", tls_1_0_record)
	}

	tls_1_1_record := []byte {22, 3, 2, 0, 0, TLS_CLIENT_HELLO, 0, 0, 0}
	result_2, err_2 := TLSDetector{}.Detect(tls_1_1_record)
	if result_2 == false {
		t.Fatalf("Expected TLSDetector{}.Detect to return true for %d\n", tls_1_1_record)
	}

	if err_2 != nil {
		t.Fatalf("Expected TLSDetector{}.Detect to return nil error for %d\n", tls_1_1_record)
	}

	tls_1_2_record := []byte {22, 3, 3, 0, 0, TLS_CLIENT_HELLO, 0, 0, 0}
	result_3, err_3 := TLSDetector{}.Detect(tls_1_2_record)
	if result_3 == false {
		t.Fatalf("Expected TLSDetector{}.Detect to return true for %d\n", tls_1_2_record)
	}

	if err_3 != nil {
		t.Fatalf("Expected TLSDetector{}.Detect to return nil error for %d\n", tls_1_2_record)
	}

	// When record is not a handshake
	non_handshake_record_type := []byte {88, 3, 3, 0, 0, TLS_CLIENT_HELLO, 0, 0, 0}
	result_4, err_4 := TLSDetector{}.Detect(non_handshake_record_type)
	if result_4 {
		t.Fatalf("Expected TLSDetector{}.Detect to return true for %d\n", non_handshake_record_type)
	}

	if err_4 != nil {
		t.Fatalf("Expected TLSDetector{}.Detect to return nil error for %d\n", non_handshake_record_type)
	}

	// When record is not a supported TLS version
	unsupported_tls_record_type := []byte {22, 3, 0, 0, 0, TLS_CLIENT_HELLO, 0, 0, 0}
	result_5, err_5 := TLSDetector{}.Detect(unsupported_tls_record_type)
	if result_5 {
		t.Fatalf("Expected TLSDetector{}.Detect to return true for %d\n", unsupported_tls_record_type)
	}

	if err_5 != nil {
		t.Fatalf("Expected TLSDetector{}.Detect to return nil error for %d\n", unsupported_tls_record_type)
	}

	// When record is not a supported TLS version
	unsupported_handshake_type_record := []byte {22, 3, 3, 0, 0, 88, 0, 0, 0}
	result_6, err_6 := TLSDetector{}.Detect(unsupported_handshake_type_record)
	if result_6 {
		t.Fatalf("Expected TLSDetector{}.Detect to return true for %d\n", unsupported_handshake_type_record)
	}

	if err_6 != nil {
		t.Fatalf("Expected TLSDetector{}.Detect to return nil error for %d\n", unsupported_handshake_type_record)
	}
}

func TestTLSDetector_Detect_ShortHeader(t *testing.T) {
	record := []byte {22, 3, 1, 0, 0}

	_, err := TLSDetector{}.Detect(record)

	if err == nil {
		t.Fatalf("Expected TLSDetector{}.Detect to return an error for %d\n", record)
	}
}