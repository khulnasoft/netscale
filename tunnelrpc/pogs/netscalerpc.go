package pogs

import (
	"github.com/khulnasoft/netscale/tunnelrpc"
	capnp "zombiezen.com/go/capnproto2"
	"zombiezen.com/go/capnproto2/rpc"
)

type NetscaleServer interface {
	SessionManager
	ConfigurationManager
}

type NetscaleServer_PogsImpl struct {
	SessionManager_PogsImpl
	ConfigurationManager_PogsImpl
}

func NetscaleServer_ServerToClient(s SessionManager, c ConfigurationManager) tunnelrpc.NetscaleServer {
	return tunnelrpc.NetscaleServer_ServerToClient(NetscaleServer_PogsImpl{
		SessionManager_PogsImpl:       SessionManager_PogsImpl{s},
		ConfigurationManager_PogsImpl: ConfigurationManager_PogsImpl{c},
	})
}

type NetscaleServer_PogsClient struct {
	SessionManager_PogsClient
	ConfigurationManager_PogsClient
	Client capnp.Client
	Conn   *rpc.Conn
}

func NewNetscaleServer_PogsClient(client capnp.Client, conn *rpc.Conn) NetscaleServer_PogsClient {
	sessionManagerClient := SessionManager_PogsClient{
		Client: client,
		Conn:   conn,
	}
	configManagerClient := ConfigurationManager_PogsClient{
		Client: client,
		Conn:   conn,
	}
	return NetscaleServer_PogsClient{
		SessionManager_PogsClient:       sessionManagerClient,
		ConfigurationManager_PogsClient: configManagerClient,
		Client:                          client,
		Conn:                            conn,
	}
}

func (c NetscaleServer_PogsClient) Close() error {
	c.Client.Close()
	return c.Conn.Close()
}
