module VimSdk
  BASE_VERSION = "vmodl.version.version0"
  VERSION1     = "vmodl.version.version1"

  XMLNS_XSD = "http://www.w3.org/2001/XMLSchema"
  XMLNS_XSI = "http://www.w3.org/2001/XMLSchema-instance"
  XMLNS_VMODL_BASE = "urn:vim25"

  XML_ENCODING = "UTF-8"
  XML_HEADER = "<?xml version=\"1.0\" encoding=\"#{XML_ENCODING}\"?>"

  XMLNS_SOAPENC = "http://schemas.xmlsoap.org/soap/encoding/"
  XMLNS_SOAPENV = "http://schemas.xmlsoap.org/soap/envelope/"

  SOAP_NAMESPACE_MAP = { XMLNS_SOAPENC => 'soapenc',
                         XMLNS_SOAPENV => 'soapenv',
                         XMLNS_XSI     => 'xsi',
                         XMLNS_XSD     => 'xsd'}

  SOAP_ENVELOPE_TAG="#{SOAP_NAMESPACE_MAP[XMLNS_SOAPENV]}:Envelope"
  SOAP_HEADER_TAG="#{SOAP_NAMESPACE_MAP[XMLNS_SOAPENV]}:Header"
  SOAP_FAULT_TAG="#{SOAP_NAMESPACE_MAP[XMLNS_SOAPENV]}:Fault"
  SOAP_BODY_TAG="#{SOAP_NAMESPACE_MAP[XMLNS_SOAPENV]}:Body"
  SOAP_ENVELOPE_START = "<#{SOAP_ENVELOPE_TAG} #{SOAP_NAMESPACE_MAP.collect { |namespace, prefix| "xmlns:#{prefix}=\"#{namespace}\"" }.join(" ")}>\n"
  SOAP_ENVELOPE_END = "\n</#{SOAP_ENVELOPE_TAG}>"
  SOAP_HEADER_START="<#{SOAP_HEADER_TAG}>"
  SOAP_HEADER_END="</#{SOAP_HEADER_TAG}>"
  SOAP_BODY_START="<#{SOAP_BODY_TAG}>"
  SOAP_BODY_END="</#{SOAP_BODY_TAG}>"
  SOAP_START = "#{SOAP_ENVELOPE_START}#{SOAP_BODY_START}\n"
  SOAP_END = "\n#{SOAP_BODY_END}#{SOAP_ENVELOPE_END}"
end