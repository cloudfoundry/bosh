package settings

import (
	"encoding/json"
	"path/filepath"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const concreteServiceLogTag = "concreteService"

type SettingsFetcher func() (Settings, error)

type concreteServiceProvider struct{}

func NewServiceProvider() concreteServiceProvider {
	return concreteServiceProvider{}
}

func (provider concreteServiceProvider) NewService(
	fs boshsys.FileSystem,
	dir string,
	fetcher SettingsFetcher,
	defaultNetworkDelegate DefaultNetworkDelegate,
	logger boshlog.Logger,
) Service {
	return NewService(
		fs,
		filepath.Join(dir, "settings.json"),
		fetcher,
		defaultNetworkDelegate,
		logger,
	)
}

type concreteService struct {
	fs                     boshsys.FileSystem
	settingsPath           string
	settings               Settings
	settingsFetcher        SettingsFetcher
	defaultNetworkDelegate DefaultNetworkDelegate
	logger                 boshlog.Logger
}

func NewService(
	fs boshsys.FileSystem,
	settingsPath string,
	settingsFetcher SettingsFetcher,
	defaultNetworkDelegate DefaultNetworkDelegate,
	logger boshlog.Logger,
) (service Service) {
	return &concreteService{
		fs:                     fs,
		settingsPath:           settingsPath,
		settings:               Settings{},
		settingsFetcher:        settingsFetcher,
		defaultNetworkDelegate: defaultNetworkDelegate,
		logger:                 logger,
	}
}

func (s *concreteService) LoadSettings() error {
	s.logger.Debug(concreteServiceLogTag, "Loading settings from fetcher")

	newSettings, fetchErr := s.settingsFetcher()
	if fetchErr != nil {
		s.logger.Error(concreteServiceLogTag, "Failed loading settings via fetcher: %v", fetchErr)

		existingSettingsJSON, readError := s.fs.ReadFile(s.settingsPath)
		if readError != nil {
			s.logger.Error(concreteServiceLogTag, "Failed reading settings from file %s", readError.Error())
			return bosherr.WrapError(fetchErr, "Invoking settings fetcher")
		}

		s.logger.Debug(concreteServiceLogTag, "Successfully read settings from file")

		err := json.Unmarshal(existingSettingsJSON, &s.settings)
		if err != nil {
			s.logger.Error(concreteServiceLogTag, "Failed unmarshalling settings from file %s", err.Error())
			return bosherr.WrapError(fetchErr, "Invoking settings fetcher")
		}

		err = s.checkAtMostOneDynamicNetwork(s.settings)
		if err != nil {
			return err
		}

		return nil
	}

	s.logger.Debug(concreteServiceLogTag, "Successfully received settings from fetcher")

	err := s.checkAtMostOneDynamicNetwork(newSettings)
	if err != nil {
		return err
	}

	s.settings = newSettings

	newSettingsJSON, err := json.Marshal(newSettings)
	if err != nil {
		return bosherr.WrapError(err, "Marshalling settings json")
	}

	err = s.fs.WriteFile(s.settingsPath, newSettingsJSON)
	if err != nil {
		return bosherr.WrapError(err, "Writing setting json")
	}

	return nil
}

func (s concreteService) checkAtMostOneDynamicNetwork(settings Settings) error {
	var foundOneDynamicNetwork bool

	for _, network := range settings.Networks {
		// Currently proper support for multiple dynamic networks is not possible
		// because CPIs (e.g. AWS and OpenStack) do not include MAC address
		// for dynamic networks and that is the only way to reliably determine
		// network to interface to IP mapping
		if network.IsDynamic() {
			if foundOneDynamicNetwork {
				return bosherr.New("Multiple dynamic networks are not supported")
			}
			foundOneDynamicNetwork = true
		}
	}

	return nil
}

// GetSettings returns setting even if it fails to resolve IPs for dynamic networks.
func (s *concreteService) GetSettings() Settings {
	for networkName, network := range s.settings.Networks {
		if !network.IsDynamic() {
			continue
		}

		// Ideally this would be GetNetworkByMACAddress(mac string)
		resolvedNetwork, err := s.defaultNetworkDelegate.GetDefaultNetwork()
		if err != nil {
			s.logger.Error(concreteServiceLogTag, "Failed retrieving default network %s", err.Error())
			break
		}

		// resolvedNetwork does not have all information for a network
		network.IP = resolvedNetwork.IP
		network.Netmask = resolvedNetwork.Netmask
		network.Gateway = resolvedNetwork.Gateway

		s.settings.Networks[networkName] = network
	}

	return s.settings
}

func (s *concreteService) InvalidateSettings() error {
	err := s.fs.RemoveAll(s.settingsPath)
	if err != nil {
		return bosherr.WrapError(err, "Removing settings file")
	}

	return nil
}
