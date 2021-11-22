// SPDX-License-Identifier: Apache-2.0

package cloud

import (
	"context"
	"fmt"
	"os"

	"github.com/cloudflare/cloudflare-go"
)

var api *cloudflare.API
var zoneID string
var ourDomain string

func cloudflareSetup() {
	var err error
	apiToken := os.Getenv("CLOUDFLARE_API_TOKEN")
	api, err = cloudflare.NewWithAPIToken(apiToken)
	if err != nil {
		l.Fatal(err)
	}

	ourDomain = os.Getenv("CLOUDFLARE_DOMAIN")
	zoneID, err = api.ZoneIDByName(ourDomain)
	if err != nil {
		l.Fatal(err)
	}
}

// CreateDNS creates an A record for org.ourdomain.tld
func CreateDNS(org string, ip string) error {
	proxied := false
	_, err := api.CreateDNSRecord(context.Background(), zoneID, cloudflare.DNSRecord{
		Type:    "A",
		Name:    fqdn(org),
		Content: ip,
		TTL:     3600,
		Proxied: &proxied,
	})
	return err
}

// DeleteDNS deletes the A record for org.ourdomain.tld
func DeleteDNS(org string) error {
	dnsID, err := getDNSID(org)
	if err != nil {
		return err
	}
	return api.DeleteDNSRecord(context.Background(), zoneID, dnsID)
}

func getDNSID(org string) (string, error) {
	filter := cloudflare.DNSRecord{Name: fqdn(org)}
	records, err := api.DNSRecords(context.Background(), zoneID, filter)
	if err != nil {
		return "", err
	}

	return records[0].ID, nil
}

func fqdn(org string) string {
	return fmt.Sprintf("%s.%s", org, ourDomain)
}
