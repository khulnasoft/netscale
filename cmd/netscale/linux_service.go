//go:build linux

package main

import (
	"fmt"
	"os"

	"github.com/rs/zerolog"
	"github.com/urfave/cli/v2"

	"github.com/khulnasoft/netscale/cmd/netscale/cliutil"
	"github.com/khulnasoft/netscale/cmd/netscale/tunnel"
	"github.com/khulnasoft/netscale/config"
	"github.com/khulnasoft/netscale/logger"
)

func runApp(app *cli.App, graceShutdownC chan struct{}) {
	app.Commands = append(app.Commands, &cli.Command{
		Name:  "service",
		Usage: "Manages the netscale system service",
		Subcommands: []*cli.Command{
			{
				Name:   "install",
				Usage:  "Install netscale as a system service",
				Action: cliutil.ConfiguredAction(installLinuxService),
				Flags: []cli.Flag{
					noUpdateServiceFlag,
				},
			},
			{
				Name:   "uninstall",
				Usage:  "Uninstall the netscale service",
				Action: cliutil.ConfiguredAction(uninstallLinuxService),
			},
		},
	})
	app.Run(os.Args)
}

// The directory and files that are used by the service.
// These are hard-coded in the templates below.
const (
	serviceConfigDir         = "/etc/netscale"
	serviceConfigFile        = "config.yml"
	serviceCredentialFile    = "cert.pem"
	serviceConfigPath        = serviceConfigDir + "/" + serviceConfigFile
	netscaleService       = "netscale.service"
	netscaleUpdateService = "netscale-update.service"
	netscaleUpdateTimer   = "netscale-update.timer"
)

var systemdAllTemplates = map[string]ServiceTemplate{
	netscaleService: {
		Path: fmt.Sprintf("/etc/systemd/system/%s", netscaleService),
		Content: `[Unit]
Description=netscale
After=network.target

[Service]
TimeoutStartSec=0
Type=notify
ExecStart={{ .Path }} --no-autoupdate{{ range .ExtraArgs }} {{ . }}{{ end }}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
`,
	},
	netscaleUpdateService: {
		Path: fmt.Sprintf("/etc/systemd/system/%s", netscaleUpdateService),
		Content: `[Unit]
Description=Update netscale
After=network.target

[Service]
ExecStart=/bin/bash -c '{{ .Path }} update; code=$?; if [ $code -eq 11 ]; then systemctl restart netscale; exit 0; fi; exit $code'
`,
	},
	netscaleUpdateTimer: {
		Path: fmt.Sprintf("/etc/systemd/system/%s", netscaleUpdateTimer),
		Content: `[Unit]
Description=Update netscale

[Timer]
OnCalendar=daily

[Install]
WantedBy=timers.target
`,
	},
}

var sysvTemplate = ServiceTemplate{
	Path:     "/etc/init.d/netscale",
	FileMode: 0755,
	Content: `#!/bin/sh
# For RedHat and cousins:
# chkconfig: 2345 99 01
# description: netscale
# processname: {{.Path}}
### BEGIN INIT INFO
# Provides:          {{.Path}}
# Required-Start:
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: netscale
# Description:       netscale agent
### END INIT INFO
name=$(basename $(readlink -f $0))
cmd="{{.Path}} --pidfile /var/run/$name.pid {{ range .ExtraArgs }} {{ . }}{{ end }}"
pid_file="/var/run/$name.pid"
stdout_log="/var/log/$name.log"
stderr_log="/var/log/$name.err"
[ -e /etc/sysconfig/$name ] && . /etc/sysconfig/$name
get_pid() {
    cat "$pid_file"
}
is_running() {
    [ -f "$pid_file" ] && ps $(get_pid) > /dev/null 2>&1
}
case "$1" in
    start)
        if is_running; then
            echo "Already started"
        else
            echo "Starting $name"
            $cmd >> "$stdout_log" 2>> "$stderr_log" &
            echo $! > "$pid_file"
        fi
    ;;
    stop)
        if is_running; then
            echo -n "Stopping $name.."
            kill $(get_pid)
            for i in {1..10}
            do
                if ! is_running; then
                    break
                fi
                echo -n "."
                sleep 1
            done
            echo
            if is_running; then
                echo "Not stopped; may still be shutting down or shutdown may have failed"
                exit 1
            else
                echo "Stopped"
                if [ -f "$pid_file" ]; then
                    rm "$pid_file"
                fi
            fi
        else
            echo "Not running"
        fi
    ;;
    restart)
        $0 stop
        if is_running; then
            echo "Unable to stop, will not attempt to start"
            exit 1
        fi
        $0 start
    ;;
    status)
        if is_running; then
            echo "Running"
        else
            echo "Stopped"
            exit 1
        fi
    ;;
    *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
exit 0
`,
}

var (
	noUpdateServiceFlag = &cli.BoolFlag{
		Name:  "no-update-service",
		Usage: "Disable auto-update of the netscale linux service, which restarts the server to upgrade for new versions.",
		Value: false,
	}
)

func isSystemd() bool {
	if _, err := os.Stat("/run/systemd/system"); err == nil {
		return true
	}
	return false
}

func installLinuxService(c *cli.Context) error {
	log := logger.CreateLoggerFromContext(c, logger.EnableTerminalLog)

	etPath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("error determining executable path: %v", err)
	}
	templateArgs := ServiceTemplateArgs{
		Path: etPath,
	}

	// Check if the "no update flag" is set
	autoUpdate := !c.IsSet(noUpdateServiceFlag.Name)

	var extraArgsFunc func(c *cli.Context, log *zerolog.Logger) ([]string, error)
	if c.NArg() == 0 {
		extraArgsFunc = buildArgsForConfig
	} else {
		extraArgsFunc = buildArgsForToken
	}

	extraArgs, err := extraArgsFunc(c, log)
	if err != nil {
		return err
	}

	templateArgs.ExtraArgs = extraArgs

	switch {
	case isSystemd():
		log.Info().Msgf("Using Systemd")
		err = installSystemd(&templateArgs, autoUpdate, log)
	default:
		log.Info().Msgf("Using SysV")
		err = installSysv(&templateArgs, autoUpdate, log)
	}

	if err == nil {
		log.Info().Msg("Linux service for netscale installed successfully")
	}
	return err
}

func buildArgsForConfig(c *cli.Context, log *zerolog.Logger) ([]string, error) {
	if err := ensureConfigDirExists(serviceConfigDir); err != nil {
		return nil, err
	}

	src, _, err := config.ReadConfigFile(c, log)
	if err != nil {
		return nil, err
	}

	// can't use context because this command doesn't define "credentials-file" flag
	configPresent := func(s string) bool {
		val, err := src.String(s)
		return err == nil && val != ""
	}
	if src.TunnelID == "" || !configPresent(tunnel.CredFileFlag) {
		return nil, fmt.Errorf(`Configuration file %s must contain entries for the tunnel to run and its associated credentials:
tunnel: TUNNEL-UUID
credentials-file: CREDENTIALS-FILE
`, src.Source())
	}
	if src.Source() != serviceConfigPath {
		if exists, err := config.FileExists(serviceConfigPath); err != nil || exists {
			return nil, fmt.Errorf("Possible conflicting configuration in %[1]s and %[2]s. Either remove %[2]s or run `netscale --config %[2]s service install`", src.Source(), serviceConfigPath)
		}

		if err := copyFile(src.Source(), serviceConfigPath); err != nil {
			return nil, fmt.Errorf("failed to copy %s to %s: %w", src.Source(), serviceConfigPath, err)
		}
	}

	return []string{
		"--config", "/etc/netscale/config.yml", "tunnel", "run",
	}, nil
}

func installSystemd(templateArgs *ServiceTemplateArgs, autoUpdate bool, log *zerolog.Logger) error {
	var systemdTemplates []ServiceTemplate
	if autoUpdate {
		systemdTemplates = []ServiceTemplate{
			systemdAllTemplates[netscaleService],
			systemdAllTemplates[netscaleUpdateService],
			systemdAllTemplates[netscaleUpdateTimer],
		}
	} else {
		systemdTemplates = []ServiceTemplate{
			systemdAllTemplates[netscaleService],
		}
	}

	for _, serviceTemplate := range systemdTemplates {
		err := serviceTemplate.Generate(templateArgs)
		if err != nil {
			log.Err(err).Msg("error generating service template")
			return err
		}
	}
	if err := runCommand("systemctl", "enable", netscaleService); err != nil {
		log.Err(err).Msgf("systemctl enable %s error", netscaleService)
		return err
	}

	if autoUpdate {
		if err := runCommand("systemctl", "start", netscaleUpdateTimer); err != nil {
			log.Err(err).Msgf("systemctl start %s error", netscaleUpdateTimer)
			return err
		}
	}

	if err := runCommand("systemctl", "daemon-reload"); err != nil {
		log.Err(err).Msg("systemctl daemon-reload error")
		return err
	}
	return runCommand("systemctl", "start", netscaleService)
}

func installSysv(templateArgs *ServiceTemplateArgs, autoUpdate bool, log *zerolog.Logger) error {
	confPath, err := sysvTemplate.ResolvePath()
	if err != nil {
		log.Err(err).Msg("error resolving system path")
		return err
	}

	if autoUpdate {
		templateArgs.ExtraArgs = append([]string{"--autoupdate-freq 24h0m0s"}, templateArgs.ExtraArgs...)
	} else {
		templateArgs.ExtraArgs = append([]string{"--no-autoupdate"}, templateArgs.ExtraArgs...)
	}

	if err := sysvTemplate.Generate(templateArgs); err != nil {
		log.Err(err).Msg("error generating system template")
		return err
	}
	for _, i := range [...]string{"2", "3", "4", "5"} {
		if err := os.Symlink(confPath, "/etc/rc"+i+".d/S50et"); err != nil {
			continue
		}
	}
	for _, i := range [...]string{"0", "1", "6"} {
		if err := os.Symlink(confPath, "/etc/rc"+i+".d/K02et"); err != nil {
			continue
		}
	}
	return runCommand("service", "netscale", "start")
}

func uninstallLinuxService(c *cli.Context) error {
	log := logger.CreateLoggerFromContext(c, logger.EnableTerminalLog)

	var err error
	switch {
	case isSystemd():
		log.Info().Msg("Using Systemd")
		err = uninstallSystemd(log)
	default:
		log.Info().Msg("Using SysV")
		err = uninstallSysv(log)
	}

	if err == nil {
		log.Info().Msg("Linux service for netscale uninstalled successfully")
	}
	return err
}

func uninstallSystemd(log *zerolog.Logger) error {
	// Get only the installed services
	installedServices := make(map[string]ServiceTemplate)
	for serviceName, serviceTemplate := range systemdAllTemplates {
		if err := runCommand("systemctl", "list-units", "--all", "|", "grep", serviceName); err == nil {
			installedServices[serviceName] = serviceTemplate
		} else {
			log.Info().Msgf("Service '%s' not installed, skipping its uninstall", serviceName)
		}
	}

	if _, exists := installedServices[netscaleService]; exists {
		if err := runCommand("systemctl", "disable", netscaleService); err != nil {
			log.Err(err).Msgf("systemctl disable %s error", netscaleService)
			return err
		}
		if err := runCommand("systemctl", "stop", netscaleService); err != nil {
			log.Err(err).Msgf("systemctl stop %s error", netscaleService)
			return err
		}
	}

	if _, exists := installedServices[netscaleUpdateTimer]; exists {
		if err := runCommand("systemctl", "stop", netscaleUpdateTimer); err != nil {
			log.Err(err).Msgf("systemctl stop %s error", netscaleUpdateTimer)
			return err
		}
	}

	for _, serviceTemplate := range installedServices {
		if err := serviceTemplate.Remove(); err != nil {
			log.Err(err).Msg("error removing service template")
			return err
		}
	}
	if err := runCommand("systemctl", "daemon-reload"); err != nil {
		log.Err(err).Msg("systemctl daemon-reload error")
		return err
	}
	return nil
}

func uninstallSysv(log *zerolog.Logger) error {
	if err := runCommand("service", "netscale", "stop"); err != nil {
		log.Err(err).Msg("service netscale stop error")
		return err
	}
	if err := sysvTemplate.Remove(); err != nil {
		log.Err(err).Msg("error removing service template")
		return err
	}
	for _, i := range [...]string{"2", "3", "4", "5"} {
		if err := os.Remove("/etc/rc" + i + ".d/S50et"); err != nil {
			continue
		}
	}
	for _, i := range [...]string{"0", "1", "6"} {
		if err := os.Remove("/etc/rc" + i + ".d/K02et"); err != nil {
			continue
		}
	}
	return nil
}
