package action

import bosherr "bosh/errors"

func (a sshAction) cleanupSsh(params sshParams) (value interface{}, err error) {
	userRegex, err := params.getUserRegex()
	if err != nil {
		return
	}

	err = a.platform.DeleteEphemeralUsersMatching(userRegex)
	if err != nil {
		err = bosherr.WrapError(err, "Ssh Cleanup: Deleting Ephemeral Users")
		return
	}

	value = map[string]string{
		"command": "cleanup",
		"status":  "success",
	}
	return
}
