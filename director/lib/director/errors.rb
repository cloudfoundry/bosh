# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  include Api::Http

  class ProblemHandlerError < StandardError; end

  # DirectorError is a generic exception for most of the errors originated
  # in BOSH Director.
  class DirectorError < StandardError
    # Wraps an exception to DirectorError, so it can be assigned a generic
    # error code and properly logged.
    # @param [Exception] exception
    # @return [DirectorError] Director error
    def self.create_from_exception(exception)
      if exception.kind_of?(DirectorError)
        exception
      else
        DirectorError.new(exception.message)
      end
    end

    # Creates a new subclass of DirectorError with
    # given name, error code and response code
    # @param [Fixnum] error_code Error code
    # @param [Fixnum] response_code HTTP response code
    # @return [Class]
    def self.define_error(error_code, response_code)
      Class.new(DirectorError) do
        define_method(:initialize) do |message|
          super(message)
          @error_code = error_code
          @response_code = response_code
        end
      end
    end

    attr_reader :response_code
    attr_reader :error_code

    def initialize(message = nil)
      super
      @response_code = 500
      @error_code = 100
      @format = "Director error: %s"
    end
  end

  def self.err(error_code, response_code)
    DirectorError.define_error(error_code, response_code)
  end

  TaskNotFound = err(10000, NOT_FOUND)
  TaskCancelled = err(10001, OK)

  UserNotFound = err(20000, NOT_FOUND)
  UserImmutableUsername = err(20001, BAD_REQUEST)
  UserInvalid = err(20002, BAD_REQUEST)
  UserNameTaken = err(20003, BAD_REQUEST)

  ReleaseAlreadyExists = err(30000, BAD_REQUEST)
  ReleaseExistingPackageHashMismatch = err(30001, BAD_REQUEST)
  ReleaseInvalidArchive = err(30002, BAD_REQUEST)
  ReleaseManifestNotFound = err(30003, BAD_REQUEST)
  ReleaseExistingJobHashMismatch = err(30004, BAD_REQUEST)
  ReleaseNotFound = err(30005, NOT_FOUND)
  ReleaseVersionNotFound = err(30006, NOT_FOUND)
  ReleaseInUse = err(50006, BAD_REQUEST) # TODO: why error code gap?
  ReleaseVersionInUse = err(50007, BAD_REQUEST)

  ValidationInvalidType = err(40000, BAD_REQUEST)
  ValidationMissingField = err(40001, BAD_REQUEST)
  ValidationViolatedMin = err(40002, BAD_REQUEST)
  ValidationViolatedMax = err(40003, BAD_REQUEST)

  StemcellInvalidArchive = err(50000, BAD_REQUEST)
  StemcellImageNotFound = err(50001, BAD_REQUEST)
  StemcellAlreadyExists = err(50002, BAD_REQUEST)
  StemcellNotFound = err(50003, NOT_FOUND)
  StemcellInUse = err(50004, BAD_REQUEST)

  PackageInvalidArchive = err(60000, BAD_REQUEST)

  DeploymentNotFound = err(70000, NOT_FOUND)
  InstanceNotFound = err(70001, NOT_FOUND)

  JobInvalidArchive = err(80000, BAD_REQUEST)
  JobMissingManifest = err(80001, BAD_REQUEST)
  JobMissingTemplateFile = err(80002, BAD_REQUEST)
  JobMissingPackage = err(80003, BAD_REQUEST)
  JobMissingMonit = err(80004, BAD_REQUEST)
  JobInvalidLogSpec = err(80005, BAD_REQUEST)

  NotEnoughCapacity = err(90000, BAD_REQUEST) # TODO: is this being used?
  InstanceInvalidIndex = err(90001, BAD_REQUEST)

  ResourceError = err(100001, BAD_REQUEST)
  ResourceNotFound = err(100002, NOT_FOUND)

  PropertyAlreadyExists = err(110001, BAD_REQUEST)
  PropertyInvalid = err(110002, BAD_REQUEST)
  PropertyNotFound = err(110003, NOT_FOUND)
end
