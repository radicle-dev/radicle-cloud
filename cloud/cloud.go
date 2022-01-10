// SPDX-License-Identifier: Apache-2.0

package cloud

import (
	"context"
	"crypto/rand"
	"fmt"
	"log"
	"math/big"
	"os"
	"time"

	"github.com/apenella/go-ansible/pkg/options"
	"github.com/apenella/go-ansible/pkg/playbook"
)

var l *log.Logger
var termFns map[string]func(string) error

func init() {
	l = log.New(os.Stderr, "[CLOUD]	", log.Ldate|log.Ltime|log.Lshortfile)

	termFns = map[string]func(string) error{
		"hetzner": hetznerDeleteServer,
	}
}

// Setup different cloud providers
func Setup() {
	hetznerSetup()
	cloudflareSetup()
}

// ReserveServer reserves a VPS randomly from a provider
func ReserveServer(org string) (string, string, error) {
	labels := []string{"hetzner"}
	providers := []func(string) (string, error){hetznerCreateServer}
	pickBn, err := rand.Int(rand.Reader, big.NewInt(int64(len(providers))))
	if err != nil {
		l.Fatalln(err)
	}
	pick := pickBn.Int64()
	ip, err := providers[pick](org)
	return labels[pick], ip, err
}

// TerminateOrg cleans up resources that's been created for org
func TerminateOrg(org string, provider string) bool {
	// terminate the server
	fn := termFns[provider]
	if err := fn(org); err != nil {
		return false
	}

	// delete dns record
	if err := DeleteDNS(org); err != nil {
		return false
	}

	return true
}

// RunAnsible runs the initial setup playbook on the newly spawned server
func RunAnsible(org string, ip string, retries int) error {
	sshKeyPath := os.Getenv("LOCAL_SSH_PATH")
	ansiblePlaybookConnectionOptions := &options.AnsibleConnectionOptions{
		User:         "root",
		SSHExtraArgs: fmt.Sprintf("\"-i %s\"", sshKeyPath),
	}
	ansiblePlaybookOptions := &playbook.AnsiblePlaybookOptions{
		Inventory: fmt.Sprintf("%s,", ip),
		ExtraVars: map[string]interface{}{
			"RAD_ORG":      org,
			"RAD_RPC_URL":  os.Getenv("RAD_RPC_URL"),
			"RAD_SUBGRAPH": os.Getenv("RAD_SUBGRAPH"),
			"RAD_DOMAIN":   os.Getenv("CLOUDFLARE_DOMAIN"),
		},
	}
	playbook := &playbook.AnsiblePlaybookCmd{
		Playbooks:         []string{"./ansible/setup.yml"},
		ConnectionOptions: ansiblePlaybookConnectionOptions,
		Options:           ansiblePlaybookOptions,
		//StdoutCallback:    "json",
	}
	if err := playbook.Run(context.TODO()); err != nil {
		l.Println("Error running ansible", err, "retries left", retries)
		if retries > 0 {
			time.Sleep(time.Second * 5)
			return RunAnsible(org, ip, retries-1)
		}
		return err
	}
	return nil
}
