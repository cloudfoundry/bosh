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

  class NoDiskSpace < StandardError
    attr_accessor :ok_to_retry

    def initialize(ok_to_retry)
      @ok_to_retry = ok_to_retry
    end
  end

  class DiskNotAttached < StandardError
    attr_accessor :ok_to_retry

    def initialize(ok_to_retry)
      @ok_to_retry = ok_to_retry
    end
  end

  class DiskNotFound < StandardError
    attr_accessor :ok_to_retry

    def initialize(ok_to_retry)
      @ok_to_retry = ok_to_retry
    end
  end

  [
   ["TaskNotFound", NOT_FOUND, 10000, "Task \"%s\" doesn't exist"],
   ["TaskCancelled", OK, 10001, "Task \"%s\" cancelled"],

   ["UserNotFound",          NOT_FOUND,    20000, "User \"%s\" doesn't exist"],
   ["UserImmutableUsername", BAD_REQUEST,  20001, "The username is immutable"],
   ["UserInvalid",           BAD_REQUEST,  20002, "The user is invalid: %s"],
   ["UserNameTaken",         BAD_REQUEST,  20003, "The username: %s is already taken"],

   ["ReleaseAlreadyExists",    BAD_REQUEST, 30000, "Release already exists"],
   ["ReleaseExistingPackageHashMismatch", BAD_REQUEST, 30001,
    "The existing package with the same name and version has a different hash"],
   ["ReleaseInvalidArchive",   BAD_REQUEST, 30002, "Invalid release archive, tar exit status: %s, output: %s"],
   ["ReleaseManifestNotFound", BAD_REQUEST, 30003, "Release manifest not found"],
   ["ReleaseExistingJobHashMismatch", BAD_REQUEST, 30004,
    "The existing job with the same name and version has a different hash"],
   ["ReleaseNotFound",         NOT_FOUND,   30005, "Release: \"%s\" doesn't exist"],
   ["ReleaseVersionNotFound",  NOT_FOUND,   30006, "Release \"%s\" version \"%s\" doesn't exist"],
   ["ReleaseInUse",            BAD_REQUEST, 50006, "Release: \"%s\" is in use by these deployments: %s"],
   ["ReleaseVersionInUse",     BAD_REQUEST, 50007, "Release \"%s\" version \"%s\" is in use by these deployments: %s"],

   ["ValidationInvalidType",   BAD_REQUEST, 40000, "Field: \"%s\" did not match the required type: \"%s\" in: %s"],
   ["ValidationMissingField",  BAD_REQUEST, 40001, "Required field: \"%s\" was not specified in: %s"],
   ["ValidationViolatedMin",   BAD_REQUEST, 40002, "Field: \"%s\" violated min constraint: %s"],
   ["ValidationViolatedMax",   BAD_REQUEST, 40003, "Field: \"%s\" violated max constraint: %s"],

   ["StemcellInvalidArchive",  BAD_REQUEST, 50000, "Invalid stemcell archive, tar exit status: %s, output: %s"],
   ["StemcellInvalidImage",    BAD_REQUEST, 50001, "Invalid stemcell image"],
   ["StemcellAlreadyExists",   BAD_REQUEST, 50002,
    "Stemcell \"%s\":\"%s\" already exists, increment the version if it has changed"],
   ["StemcellNotFound",        NOT_FOUND,   50003, "Stemcell: \"%s\":\"%s\" doesn't exist"],
   ["StemcellInUse",           BAD_REQUEST, 50004, "Stemcell: \"%s\":\"%s\" is in use by these deployments: %s"],

   ["PackageInvalidArchive",   BAD_REQUEST, 60000, "Invalid package archive, tar exit status: %s, output: %s"],

   ["DeploymentNotFound",      NOT_FOUND,   70000, "Deployment \"%s\" doesn't exist"],
   ["InstanceNotFound",        NOT_FOUND,   70001, "Job instance \"%s\" doesn't exist"],

   ["JobInvalidArchive",       BAD_REQUEST, 80000, "Job: \"%s\" invalid archive, tar exit status: %s, output: %s"],
   ["JobMissingManifest",      BAD_REQUEST, 80001, "Job: \"%s\" missing job manifest"],
   ["JobMissingTemplateFile",  BAD_REQUEST, 80002, "Job: \"%s\" missing template file: \"%s\""],
   ["JobMissingPackage",       BAD_REQUEST, 80003, "Job: \"%s\" missing package: \"%s\""],
   ["JobMissingMonit",         BAD_REQUEST, 80004, "Job: \"%s\" missing monit configuration"],
   ["JobInvalidLogSpec",       BAD_REQUEST, 80005, "Job: \"%s\" invalid logs spec format"],

   ["NotEnoughCapacity",       BAD_REQUEST, 90000, "%s"],
   ["InstanceInvalidIndex",    BAD_REQUEST, 90001, "Invalid job index: \"%s\""],
   ["InvalidRequest",          BAD_REQUEST, 90002, "Invalid request: \"%s\""],

   ["ResourceError",           BAD_REQUEST,  100001, "Error fetching resource %s: %s"],
   ["ResourceNotFound",        NOT_FOUND,    100002, "Resource %s not found"],

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
