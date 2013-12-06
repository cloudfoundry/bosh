package applier

type LogrotateDelegate interface {
	SetupLogrotate(groupName, basePath, size string) (err error)
}
