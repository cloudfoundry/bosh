module Bosh::Director
  include Api::Http

  class ProblemHandlerError < StandardError; end
  class AuthenticationError < StandardError; end

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

  # User management
  UserNotFound = err(20000, NOT_FOUND)
  UserImmutableUsername = err(20001)
  UserInvalid = err(20002)
  UserNameTaken = err(20003)
  UserManagementNotSupported = err(20004)

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
  ReleaseVersionInvalid = err(30010)
  ReleaseNotMatchingManifest = err(30011)
  ReleaseInvalidPackage = err(30012)
  ReleaseExistingJobFingerprintMismatch = err(30013)
  ReleaseVersionCommitHashMismatch = err(30014)
  ReleaseSha1DoesNotMatch = err(30015)
  ReleasePackageDependencyKeyMismatch = err(30016)

  ValidationInvalidType = err(40000)
  ValidationMissingField = err(40001)
  ValidationViolatedMin = err(40002)
  ValidationViolatedMax = err(40003)
  ValidationExtraField = err(40004)
  ValidationInvalidValue = err(40005)

  StemcellInvalidArchive = err(50000)
  StemcellImageNotFound = err(50001)
  StemcellAlreadyExists = err(50002)
  StemcellNotFound = err(50003, NOT_FOUND)
  StemcellInUse = err(50004)
  StemcellAliasAlreadyExists = err(50005)
  StemcellBothNameAndOS = err(50006)
  StemcellSha1DoesNotMatch = err(50007)
  StemcellNotSupported = err(50008)

  PackageInvalidArchive = err(60000)
  PackageMissingSourceCode = err(60001)
  CompiledPackageDeletionFailed = err(60002)

  # Models
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
  JobNotFound = err(70009, NOT_FOUND)
  ContextIdViolatedMax = err(70010)
  VariableSetNotFound = err(70011)

  # Extracting job from a release
  JobInvalidArchive = err(80000)
  JobMissingManifest = err(80001)
  JobMissingTemplateFile = err(80002)
  JobMissingPackage = err(80003)
  JobMissingMonit = err(80004)
  JobInvalidLogSpec = err(80005)
  JobTemplateBindingFailed = err(80006)
  JobInvalidPropertySpec = err(80008)
  InstanceGroupInvalidPropertyMapping = err(80009)
  JobIncompatibleSpecs = err(80010)
  JobPackageCollision = err(80011)
  JobInvalidPackageSpec = err(80012)
  JobInvalidLinkSpec = err(80013)
  JobDuplicateLinkName = err(80014)

  ResourceError = err(100001)
  ResourceNotFound = err(100002, NOT_FOUND)

  # Director property management
  PropertyAlreadyExists = err(110001)
  PropertyInvalid = err(110002)
  PropertyNotFound = err(110003, NOT_FOUND)

  CompilationConfigUnknownNetwork = err(120001)
  CompilationConfigInvalidAvailabilityZone = err(120002)
  CompilationConfigInvalidVmType = err(120003)
  CompilationConfigCloudPropertiesNotAllowed = err(120004)
  CompilationConfigInvalidVmExtension = err(120005)
  CompilationConfigVmTypeRequired = err(120004)

  # Manifest parsing: network section
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
  NetworkReservationNotEnoughCapacity = err(130011)
  NetworkReservationIpOutsideSubnet = err(130012)
  NetworkReservationIpReserved = err(130013)

  # Manifest parsing: job section
  InstanceGroupMissingRelease = err(140001)
  InstanceGroupUnknownRelease = err(140002)
  InstanceGroupUnknownResourcePool = err(140003)
  InstanceGroupUnknownVmType = err(140004)
  InstanceGroupUnknownStemcell = err(140005)
  JobInvalidInstanceIndex = err(140006)
  InstanceGroupInvalidInstanceState = err(140007)
  InstanceGroupInvalidState = err(140008)
  JobMissingNetwork = err(140009)
  InstanceGroupInvalidTemplates = err(140010)
  JobInvalidLifecycle = err(140011)
  InstanceGroupUnknownDiskType = err(140012)
  InstanceGroupInvalidPersistentDisk = err(140013)
  JobMissingLink = err(140014)
  UnusedProvidedLink = err(140015)
  JobInvalidAvailabilityZone = err(140016)
  JobMissingAvailabilityZones = err(140017)
  JobUnknownAvailabilityZone = err(140018)
  InstanceGroupAmbiguousEnv = err(140019)
  JobBothInstanceGroupAndJob = err(140020)
  JobInstanceIgnored = err(140021)

  # Manifest parsing: job networks section
  JobUnknownNetwork = err(150001)
  InstanceGroupNetworkInstanceIpMismatch = err(150002)
  JobNetworkInvalidDefault = err(150003)
  JobNetworkMultipleDefaults = err(150004)
  JobNetworkMissingDefault = err(150005)
  JobNetworkMissingRequiredAvailabilityZone= err(150006)
  JobStaticIpsFromInvalidAvailabilityZone= err(150007)
  JobStaticIPNotSupportedOnDynamicNetwork= err(150008)
  JobInvalidStaticIPs = err(150009)

  #Network
  NetworkOverlappingSubnets = err(160001)
  NetworkInvalidRange = err(160002)
  NetworkInvalidGateway = err(160003)
  NetworkInvalidDns = err(160004)
  NetworkReservedIpOutOfRange = err(160005)
  NetworkStaticIpOutOfRange = err(160006)
  NetworkSubnetUnknownAvailabilityZone = err(160007)
  NetworkInvalidProperty = err(160008)
  NetworkSubnetInvalidAvailabilityZone = err(160009)
  NetworkInvalidIpRangeFormat = err(160010)

  # ResourcePool
  ResourcePoolUnknownNetwork = err(170001)
  ResourcePoolNotEnoughCapacity = err(170002)

  # UpdateConfig
  UpdateConfigInvalidWatchTime = err(180001)

  # Deployment
  DeploymentAmbiguousReleaseSpec = err(190001)
  DeploymentDuplicateReleaseName = err(190002)
  DeploymentDuplicateResourcePoolName = err(190003)
  DeploymentDuplicateVmTypeName = err(190004)
  DeploymentDuplicateVmExtensionName = err(190005)
  DeploymentCanonicalJobNameTaken = err(190006)
  DeploymentCanonicalNetworkNameTaken = err(190007)
  DeploymentNoNetworks = err(190008)
  DeploymentCanonicalNameTaken = err(190009)
  DeploymentInvalidNetworkType = err(190010)
  DeploymentUnknownTemplate = err(190011)
  DeploymentInvalidDiskSpecification = err(190012)
  DeploymentDuplicateDiskTypeName = err(190013)
  DeploymentInvalidProperty = err(190014)
  DeploymentNoResourcePools = err(190015)
  DeploymentInvalidLink = err(190016)
  DeploymentDuplicateAvailabilityZoneName = err(190017)
  DeploymentInvalidMigratedFromJob = err(190018)
  DeploymentInvalidResourceSpecification = err(190019)
  DeploymentIgnoredInstancesModification = err(190020)
  DeploymentIgnoredInstancesDeletion = err(190021)

  # DiskType
  DiskTypeInvalidDiskSize = err(200001)

  CloudDiskNotAttached = err(390001)
  CloudDiskMissing = err(390002)
  CloudNotEnoughDiskSpace = err(390003)

  # Agent errors
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
  AgentInvalidTaskResult = err(400011)
  AgentUnsupportedAction = err(400012)
  AgentUploadBlobUnableToOpenFile = err(400013)

  # Cloud check task errors
  CloudcheckTooManySimilarProblems = err(410001)
  CloudcheckResolutionNotProvided = err(410002)
  CloudcheckInvalidResolutionFormat = err(410003)

  # DNS
  DnsInvalidCanonicalName = err(420001)

  # PackageCompilation
  PackageCompilationNotEnoughWorkersForReuse = err(430002)
  PackageCompilationNotFound = err(430003)

  BadManifest = err(440001)

  # RPC
  RpcRemoteException = err(450001)
  RpcTimeout = err(450002)

  SystemError = err(500000, INTERNAL_SERVER_ERROR)
  NotEnoughDiskSpace = err(500001, INTERNAL_SERVER_ERROR)

  # Run errand errors
  RunErrandError = err(510000)

  # Disk errors
  DeletingPersistentDiskError = err(520000)
  AttachDiskErrorUnknownInstance = err(520001)
  AttachDiskNoPersistentDisk =  err(520002)
  AttachDiskInvalidInstanceState = err(520003)

  # Addons
  RuntimeAmbiguousReleaseSpec = err(530000)
  RuntimeInvalidReleaseVersion = err(530001)
  AddonReleaseNotListedInReleases = err(530002)
  RuntimeInvalidDeploymentRelease = err(530003)
  AddonIncompleteFilterJobSection = err(530004)
  AddonIncompleteFilterStemcellSection = err(530005)
  AddonDeploymentFilterNotAllowed = err(530006)
  RuntimeConfigParseError = err(530006)

  # Config server errors
  ConfigServerFetchError = err(540001)
  ConfigServerMissingName = err(540002)
  ConfigServerUnknownError = err(540003)
  ConfigServerIncorrectNameSyntax = err(540004)
  ConfigServerGenerationError = err(540005)
  ConfigServerDeploymentNameMissing = err(540006)
  ConfigServerIncorrectVariablePlacement = err(540007)
  ConfigServerInconsistentVariableState = err(540008)

  # CPI config
  CpiDuplicateName = err(550000)

  # Variables
  VariablesInvalidFormat = err(560000)

  # Authorization errors
  UnauthorizedToAccessDeployment = err(600000, UNAUTHORIZED)

  # UAA
  UAAAuthorizationError = err(610000)

  # Invalid YAML
  InvalidYamlError = err(710000)

  # Resolving Links
  LinkLookupError = err(810000)
end
