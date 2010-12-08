module Bosh::Director

  class DirectorError < StandardError
    attr_reader :response_code
    attr_reader :error_code

    def initialize(response_code, error_code, format, *args)
      @response_code = response_code
      @error_code = error_code
      msg = sprintf(format, *args)
      super(msg)
    end
  end

  class ServerError < StandardError
    attr_reader :omit_stack

    def initialize(msg, options = {})
      super(msg)
      @omit_stack = options[:omit_stack]
    end

  end

  [
    ["TaskNotFound", NOT_FOUND, 10000, "Task \"%s\" doesn't exist"],

    ["UserNotFound",          NOT_FOUND,    20000, "User \"%s\" doesn't exist"],
    ["UserImmutableUsername", BAD_REQUEST,  20001, "The username is immutable"],
    ["UserInvalid",           BAD_REQUEST,  20002, "The user is invalid: %s"],

    ["ReleaseAlreadyExists",    BAD_REQUEST, 30000, "Release already exists"],
    ["ReleaseExistingPackageHashMismatch", BAD_REQUEST, 30001,
        "The existing package with the same name and version has a different hash"],
    ["ReleaseInvalidArchive",   BAD_REQUEST, 30002, "Invalid release archive"],
    ["ReleaseManifestNotFound", BAD_REQUEST, 30003, "Release manifest not found"],

    ["ValidationInvalidType",   BAD_REQUEST, 40000, "Field: \"%s\" did not match the required type: \"%s\" in: %s"],
    ["ValidationMissingField",  BAD_REQUEST, 40001, "Required field: \"%s\" was not specified in: %s"],

    ["StemcellInvalidArchive",  BAD_REQUEST, 50000, "Invalid stemcell archive, tar exit status: %s, output: %s"],
    ["StemcellInvalidImage",    BAD_REQUEST, 50001, "Invalid stemcell image"],
    ["StemcellAlreadyExists",   BAD_REQUEST, 50002, "Stemcell already exists, increment the version if it has changed"],
  ].each do |e|
    class_name, response_code, error_code, format = e

    klass = Class.new DirectorError do
      define_method :initialize do |*args|
        super(response_code, error_code, format, *args)
      end
    end

    Bosh::Director.const_set(class_name, klass)
  end

end