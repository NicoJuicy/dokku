package cron

import (
	"fmt"

	appjson "github.com/dokku/dokku/plugins/app-json"
	"github.com/dokku/dokku/plugins/common"

	"github.com/multiformats/go-base36"
	cronparser "github.com/robfig/cron/v3"
)

var (
	// DefaultProperties is a map of all valid cron properties with corresponding default property values
	DefaultProperties = map[string]string{
		"mailfrom":    "",
		"mailto":      "",
		"maintenance": "false",
	}

	// GlobalProperties is a map of all valid global cron properties
	GlobalProperties = map[string]bool{
		"mailfrom":    true,
		"mailto":      true,
		"maintenance": true,
	}
)

// TemplateCommand is a struct that represents a cron command
type TemplateCommand struct {
	// ID is a unique identifier for the cron command
	ID string `json:"id"`

	// App is the app the cron command belongs to
	App string `json:"app"`

	// Command is the command to run
	Command string `json:"command"`

	// Schedule is the cron schedule
	Schedule string `json:"schedule"`

	// AltCommand is an alternate command to run
	AltCommand string `json:"-"`

	// LogFile is the log file to write to
	LogFile string `json:"-"`

	// Maintenance is whether the cron command is in maintenance mode
	Maintenance bool `json:"maintenance"`
}

// CronCommand returns the command to run for a given cron command
func (t TemplateCommand) CronCommand() string {
	if t.AltCommand != "" {
		if t.LogFile != "" {
			return fmt.Sprintf("%s &>> %s", t.AltCommand, t.LogFile)
		}
		return t.AltCommand
	}

	return fmt.Sprintf("dokku run --cron-id %s %s %s", t.ID, t.App, t.Command)
}

// FetchCronEntriesInput is the input for the FetchCronEntries function
type FetchCronEntriesInput struct {
	AppName       string
	AppJSON       *appjson.AppJSON
	WarnToFailure bool
}

// FetchCronEntries returns a list of cron commands for a given app
func FetchCronEntries(input FetchCronEntriesInput) ([]TemplateCommand, error) {
	appName := input.AppName
	commands := []TemplateCommand{}
	isMaintenance := reportComputedMaintenance(appName) == "true"

	if input.AppJSON == nil {
		appJSON, err := appjson.GetAppJSON(appName)
		if err != nil {
			return commands, fmt.Errorf("Unable to fetch app.json for app %s: %s", appName, err.Error())
		}

		input.AppJSON = &appJSON
	}

	if input.AppJSON.Cron == nil {
		return commands, nil
	}

	for i, c := range input.AppJSON.Cron {
		if c.Command == "" {
			if input.WarnToFailure {
				return commands, fmt.Errorf("Missing cron command for app %s (index %d)", appName, i)
			}

			common.LogWarn(fmt.Sprintf("Missing cron command for app %s (index %d)", appName, i))
			continue
		}

		if c.Schedule == "" {
			if input.WarnToFailure {
				return commands, fmt.Errorf("Missing cron schedule for app %s (index %d)", appName, i)
			}

			common.LogWarn(fmt.Sprintf("Missing cron schedule for app %s (index %d)", appName, i))
			continue
		}

		parser := cronparser.NewParser(cronparser.Minute | cronparser.Hour | cronparser.Dom | cronparser.Month | cronparser.Dow | cronparser.Descriptor)
		_, err := parser.Parse(c.Schedule)
		if err != nil {
			return commands, fmt.Errorf("Invalid cron schedule for app %s (schedule %s): %s", appName, c.Schedule, err.Error())
		}

		commands = append(commands, TemplateCommand{
			App:         appName,
			Command:     c.Command,
			Schedule:    c.Schedule,
			ID:          GenerateCommandID(appName, c),
			Maintenance: isMaintenance,
		})
	}

	return commands, nil
}

// GenerateCommandID creates a unique ID for a given app/command/schedule combination
func GenerateCommandID(appName string, c appjson.CronCommand) string {
	return base36.EncodeToStringLc([]byte(appName + "===" + c.Command + "===" + c.Schedule))
}
