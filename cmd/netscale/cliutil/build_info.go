package cliutil

import (
	"fmt"
	"runtime"

	"github.com/rs/zerolog"
)

type BuildInfo struct {
	GoOS               string `json:"go_os"`
	GoVersion          string `json:"go_version"`
	GoArch             string `json:"go_arch"`
	BuildType          string `json:"build_type"`
	NetscaleVersion string `json:"netscale_version"`
}

func GetBuildInfo(buildType, version string) *BuildInfo {
	return &BuildInfo{
		GoOS:               runtime.GOOS,
		GoVersion:          runtime.Version(),
		GoArch:             runtime.GOARCH,
		BuildType:          buildType,
		NetscaleVersion: version,
	}
}

func (bi *BuildInfo) Log(log *zerolog.Logger) {
	log.Info().Msgf("Version %s", bi.NetscaleVersion)
	if bi.BuildType != "" {
		log.Info().Msgf("Built%s", bi.GetBuildTypeMsg())
	}
	log.Info().Msgf("GOOS: %s, GOVersion: %s, GoArch: %s", bi.GoOS, bi.GoVersion, bi.GoArch)
}

func (bi *BuildInfo) OSArch() string {
	return fmt.Sprintf("%s_%s", bi.GoOS, bi.GoArch)
}

func (bi *BuildInfo) Version() string {
	return bi.NetscaleVersion
}

func (bi *BuildInfo) GetBuildTypeMsg() string {
	if bi.BuildType == "" {
		return ""
	}
	return fmt.Sprintf(" with %s", bi.BuildType)
}

func (bi *BuildInfo) UserAgent() string {
	return fmt.Sprintf("netscale/%s", bi.NetscaleVersion)
}
