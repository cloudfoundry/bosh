package drain

type DrainScriptProvider interface {
	NewDrainScript(templateName string) (drainScript DrainScript)
}
