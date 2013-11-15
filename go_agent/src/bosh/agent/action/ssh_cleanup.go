package action

func (a sshAction) cleanupSsh(params map[string]interface{}) (value interface{}, err error) {
	userRegex, err := extractStringParam(params, "user_regex")
	if err != nil {
		return
	}

	err = a.platform.DeleteEphemeralUsersMatching(userRegex)
	if err != nil {
		return
	}

	value = map[string]string{
		"command": "cleanup",
		"status":  "success",
	}
	return
}
