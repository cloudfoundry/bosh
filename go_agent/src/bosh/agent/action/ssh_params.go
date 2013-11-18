package action

type sshParams map[string]interface{}

func (params sshParams) getString(name string) (val string, err error) {
	if params[name] == nil {
		return
	}

	val, ok := params[name].(string)
	if !ok {
		err = payloadErr(name)
	}
	return
}

func (params sshParams) getSshSetupData() (user, pwd, key string, err error) {
	user, err = params.getString("user")
	if err != nil {
		return
	}

	pwd, err = params.getString("password")
	if err != nil {
		return
	}

	key, err = params.getString("public_key")
	return
}

func (params sshParams) getUserRegex() (string, error) {
	return params.getString("user_regex")
}
