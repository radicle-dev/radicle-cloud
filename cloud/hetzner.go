// SPDX-License-Identifier: Apache-2.0

package cloud

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/hetznercloud/hcloud-go/hcloud"
)

var client *hcloud.Client
var key *hcloud.SSHKey

func hetznerSetup() {
	token := os.Getenv("HETNZER_TOKEN")
	sshKeyName := os.Getenv("HETNZER_SSH_NAME")
	client = hcloud.NewClient(hcloud.WithToken(token))
	var err error
	key, _, err = client.SSHKey.GetByName(context.Background(), sshKeyName)
	if err != nil {
		panic(err)
	}
}

func hetznerCreateServer(org string) (string, error) {
	srvCreateResult, _, err := client.Server.Create(context.Background(), hcloud.ServerCreateOpts{
		Name:       org,
		Image:      &hcloud.Image{Name: "docker-ce"},
		ServerType: &hcloud.ServerType{Name: "cx11"},
		SSHKeys:    []*hcloud.SSHKey{key},
	})
	if err != nil {
		if hcloud.IsError(err, hcloud.ErrorCodeUniquenessError) {
			l.Printf("Server for org %s already reserved\n", org)
			// we already have the server so we simply return it
			var srv *hcloud.Server
			if srv, _, err = client.Server.GetByName(context.Background(), org); err != nil {
				l.Printf("Failed to retrieve already reserved server for org %s\n", org)
				return "", err
			}
			return srv.PublicNet.IPv4.IP.String(), nil
		}
		return "", err
	}

	l.Printf("Server for org %s created, waiting for it to run...\n", org)
	counter := 0
	srv := srvCreateResult.Server
	for srv.Status != "running" {
		time.Sleep(time.Second * 5)
		srv, _, _ = client.Server.GetByID(context.Background(), srv.ID)
		counter += 5
		if counter > 60 {
			return "", fmt.Errorf("timed out waiting for %s server to become \"running\"", org)
		}
	}
	l.Printf("Server for org %s is running.\n", org)

	return srv.PublicNet.IPv4.IP.String(), nil
}

func hetznerDeleteServer(org string) error {
	srv, _, err := client.Server.GetByName(context.Background(), org)
	if err != nil {
		return err
	}
	// server did not exist, consider it a re-try which had succeeded
	if srv == nil {
		return nil
	}
	_, err = client.Server.Delete(context.Background(), srv)
	return err
}
