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
        define_method(:initialize) do |*args|
          message = args[0]
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

  def self.err(error_code, response_code = BAD_REQUEST)
    DirectorError.define_error(error_code, response_code)
  end

  TaskNotFound = err(10000, NOT_FOUND)
  TaskCancelled = err(10001, OK)

  UserNotFound = err(20000, NOT_FOUND)
  UserImmutableUsername = err(20001)
  UserInvalid = err(20002)
  UserNameTaken = err(20003)

  ReleaseAlreadyExists = err(30000)
  ReleaseExistingPackageHashMismatch = err(30001)
  ReleaseInvalidArchive = err(30002)
  ReleaseManifestNotFound = err(30003)
  ReleaseExistingJobHashMismatch = err(30004)
  ReleaseNotFound = err(30005, NOT_FOUND)
  ReleaseVersionNotFound = err(30006, NOT_FOUND)
  ReleaseInUse = err(30007)
  ReleaseVersionInUse = err(30008)
  ReleaseDeleteFailed = err(30009)

  ValidationInvalidType = err(40000)
  ValidationMissingField = err(40001)
  ValidationViolatedMin = err(40002)
  ValidationViolatedMax = err(40003)

  StemcellInvalidArchive = err(50000)
  StemcellImageNotFound = err(50001)
  StemcellAlreadyExists = err(50002)
  StemcellNotFound = err(50003, NOT_FOUND)
  StemcellInUse = err(50004)

  PackageInvalidArchive = err(60000)

  DeploymentNotFound = err(70000, NOT_FOUND)
  InstanceNotFound = err(70001, NOT_FOUND)
  InstanceInvalidIndex = err(70002)
  InstanceDeploymentMissing = err(70003)
  InstanceVmMissing = err(70004)
  VmAgentIdMissing = err(70005)
  VmCloudIdMissing = err(70006)
  VmInstanceOutOfSync = err(70006)
  InstanceTargetStateUndefined = err(70007)
  SnapshotNotFound = err(70008)

  JobInvalidArchive = err(80000)
  JobMissingManifest = err(80001)
  JobMissingTemplateFile = err(80002)
  JobMissingPackage = err(80003)
  JobMissingMonit = err(80004)
  JobInvalidLogSpec = err(80005)
  JobTemplateBindingFailed = err(80006)
  JobTemplateUnpackFailed = err(80007)
  JobInvalidPropertySpec = err(80008)
  JobInvalidPropertyMapping = err(80009)
  JobIncompatibleSpecs = err(80010)

  ResourceError = err(100001)
  ResourceNotFound = err(100002, NOT_FOUND)

  PropertyAlreadyExists = err(110001)
  PropertyInvalid = err(110002)
  PropertyNotFound = err(110003, NOT_FOUND)

  CompilationConfigUnknownNetwork = err(120001)

  NetworkReservationInvalidIp = err(130001)
  NetworkReservationMissing = err(130002)
  NetworkReservationAlreadyExists = err(130003)
  NetworkReservationInvalidType = err(130004)
  NetworkReservationIpMissing = err(130005)
  NetworkReservationIpNotOwned = err(130006)
  NetworkReservationVipDefaultProvided = err(130007)
  NetworkReservationAlreadyInUse = err(130008)
  NetworkReservationWrongType = err(130009)
  NetworkReservationError = err(130010)
  NetworkReservationNotEnoughCapacity = err(130010)

  JobMissingRelease = err(140001)
  JobUnknownRelease = err(140002)
  JobUnknownResourcePool = err(140003)
  JobInvalidInstanceIndex = err(140004)
  JobInvalidInstanceState = err(140005)
  JobInvalidJobState = err(140006)
  JobMissingNetwork = err(140007)
  JobInvalidTemplates = err(140008)

  JobUnknownNetwork = err(150001)
  JobNetworkInstanceIpMismatch = err(150002)
  JobNetworkInvalidDefault = err(150003)
  JobNetworkMultipleDefaults = err(150004)
  JobNetworkMissingDefault = err(150005)

  NetworkOverlappingSubnets = err(160001)
  NetworkInvalidRange = err(160002)
  NetworkInvalidGateway = err(160003)
  NetworkInvalidDns = err(160004)
  NetworkReservedIpOutOfRange = err(160005)
  NetworkStaticIpOutOfRange = err(160006)

  ResourcePoolUnknownNetwork = err(170001)
  ResourcePoolNotEnoughCapacity = err(170002)

  UpdateConfigInvalidWatchTime = err(180001)

  DeploymentAmbiguousReleaseSpec = err(190001)
  DeploymentDuplicateReleaseName = err(190002)
  DeploymentDuplicateResourcePoolName = err(190003)
  DeploymentRenamedJobNameStillUsed = err(190004)
  DeploymentCanonicalJobNameTaken = err(190005)
  DeploymentCanonicalNetworkNameTaken = err(190006)
  DeploymentNoNetworks = err(190007)
  DeploymentCanonicalNameTaken = err(190008)
  DeploymentInvalidNetworkType = err(190009)
  DeploymentUnknownTemplate = err(190012)

  CloudDiskNotAttached = err(390001)
  CloudDiskMissing = err(390002)
  CloudNotEnoughDiskSpace = err(390003)

  AgentTaskNoBlobstoreId = err(400001)
  AgentInvalidStateFormat = err(400002)
  AgentWrongDeployment = err(400003)
  AgentUnexpectedJob = err(400004)
  AgentRenameInProgress = err(400005)
  AgentJobMismatch = err(400006)
  AgentJobNotRunning = err(400007)
  AgentJobNotStopped = err(400008)
  AgentUnexpectedDisk = err(400009)
  AgentDiskOutOfSync = err(400010)

  CloudcheckTooManySimilarProblems = err(410001)
  CloudcheckResolutionNotProvided = err(410002)
  CloudcheckInvalidResolutionFormat = err(410003)

  DnsInvalidCanonicalName = err(420001)

  PackageCompilationNetworkNotReserved = err(430001)
  PackageCompilationNotEnoughWorkersForReuse = err(430002)

  BadManifest = err(440001)

  RpcRemoteException = err(450001)
  RpcTimeout = err(450002)

  SystemError = err(500000, INTERNAL_SERVER_ERROR)
  NotEnoughDiskSpace = err(500001, INTERNAL_SERVER_ERROR)
end
