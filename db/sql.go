// SPDX-License-Identifier: Apache-2.0

package db

import (
	"database/sql"
	"log"
	"os"
	"radicle-cloud/eth"
	"time"

	_ "github.com/lib/pq" //
)

var db *sql.DB
var l *log.Logger

const (
	InitialStatus     string = "initial"
	AllocatedStatus   string = "allocated"
	SetupFailedStatus string = "setup-failed"
	RunningStatus     string = "running"
)

func init() {
	l = log.New(os.Stderr, "[DB]	", log.Ldate|log.Ltime|log.Lshortfile)
}

// Setup initializes the postgres client
func Setup() {
	tries := 5
	var err error
	conn := os.Getenv("POSTGRES")
	for tries >= 0 {
		l.Printf("Trying to connect to DB, attempt #%d\n", 6-tries)
		if tries == 0 {
			panic("Can't make connection to DB")
		}
		db, err = sql.Open("postgres", conn)
		if err != nil {
			l.Println(err)
		}
		err = db.Ping()
		if err != nil {
			tries--
			time.Sleep(time.Second * 3)
			continue
		}
		l.Println("DB connected!")
		break
	}
}

// UpsertDep upserts record for org and returns provider, ip, and status
func UpsertDep(e eth.Event) (string, string, string, error) {
	provider := ""
	ip := ""
	status := InitialStatus
	statement := `
		SELECT provider, ip, status FROM deployments
		WHERE org = $1
	`
	row := db.QueryRow(statement, e.Org)
	err := row.Scan(&provider, &ip, &status)
	if err != nil && err != sql.ErrNoRows {
		return provider, ip, status, err
	}
	// upsert deployment
	statement = `
    	INSERT INTO
    	deployments (org, expiry)
    	VALUES 		($1,  	  $2)
    	ON CONFLICT (org) DO
      	UPDATE SET expiry = $2;
  	`
	_, err = db.Exec(statement, e.Org, e.Expiry)
	return provider, ip, status, err
}

// UpdateOrgServer sets the ip of reserved server for this org
func UpdateOrgServer(org string, ip string, provider string) error {
	statement := `
		UPDATE deployments
		SET ip = $2, provider = $3, status = $4
		WHERE org = $1
	`
	_, err := db.Exec(statement, org, ip, provider, "allocated")
	return err
}

// SetStatus changes the status of the org in DB
func SetStatus(org string, status string) error {
	statement := `
		UPDATE deployments
		SET status = $2
		WHERE org = $1
	`
	_, err := db.Exec(statement, org, status)
	return err
}

// Dep struct has Org's name, its Expiry (block number), and Provider
type Dep struct {
	Org      string
	Expiry   uint64
	Provider string
}

// ListDeployments lists all deployments with ascending expiry
func ListDeployments() ([]Dep, error) {
	deps := []Dep{}
	statement := `
		SELECT org, expiry, provider FROM deployments
		ORDER BY expiry ASC
	`
	rows, err := db.Query(statement)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var d Dep
	for rows.Next() {
		err = rows.Scan(&d.Org, &d.Expiry, &d.Provider)
		if err != nil {
			return nil, err
		}
		deps = append(deps, d)
	}
	if err = rows.Err(); err != nil {
		return nil, err
	}
	return deps, nil
}

// DeleteOrg deletes deployment and events belonging to org
func DeleteOrg(org string) error {
	statement := `
		DELETE FROM deployments
		WHERE org = $1
	`
	_, err := db.Exec(statement, org)
	if err != nil {
		return err
	}
	statement = `
		DELETE FROM events
		WHERE org = $1
	`
	_, err = db.Exec(statement, org)
	return err
}

// GetProvider returns the cloud provider for the org passed to it
func GetProvider(org string) (string, error) {
	var provider string
	statement := `
		SELECT provider FROM deployments
		WHERE org = $1
	`
	row := db.QueryRow(statement, org)
	return provider, row.Scan(&provider)
}

// GetSmallestUnprocessedEvent returns smallest unprocessed emittedAt
func GetSmallestUnprocessedEvent() (uint64, error) {
	var emittedAt uint64
	statement := `
		SELECT emittedAt FROM events
		WHERE processed != $1 OR removed = $1
		ORDER BY emittedAt ASC LIMIT 1
	`
	row := db.QueryRow(statement, true)
	return emittedAt, row.Scan(&emittedAt)
}

// GetLargestProcessedEvent returns largest processed emittedAt
func GetLargestProcessedEvent() (uint64, error) {
	var emittedAt uint64
	statement := `
		SELECT emittedAt FROM events
		WHERE processed = $1
		ORDER BY emittedAt DESC LIMIT 1
	`
	row := db.QueryRow(statement, true)
	return emittedAt, row.Scan(&emittedAt)
}

// GetLastProcessedBlock returns smallestUnprocessed or largestProcessed or currentBlock
func GetLastProcessedBlock() (uint64, error) {
	lastEmittedAt, err := GetSmallestUnprocessedEvent()
	if err != nil {
		if err != sql.ErrNoRows {
			l.Println("No rows when getting smallest emittedAt", err)
		}
		lastEmittedAt, err = GetLargestProcessedEvent()
		// for processed case, we want to start looking from t+1
		return lastEmittedAt + 1, err
	}
	return lastEmittedAt, nil
}

// UpsertEvent upserts the event and overwrites 'removed' column
func UpsertEvent(e eth.Event) error {
	// upsert the org
	statement := `
    	INSERT INTO
    	events (type,	blockAndTx,	org,	emittedAt,	expiry,	removed)
    	VALUES ($1,		$2,			 $3,	$4,			$5,			 $6)
    	ON CONFLICT (blockAndTx) DO
      	UPDATE SET removed = $6;
  	`
	_, err := db.Exec(statement, e.Type.String(), e.BlockAndTx, e.Org, e.BlockNumber, e.Expiry, e.Removed)
	return err
}

// MarkEventProcessed sets processed to true for event of this blockAndTx
func MarkEventProcessed(blockAndTx []byte) error {
	statement := `
		UPDATE events
		SET processed = $2
		WHERE blockAndTx = $1
	`
	_, err := db.Exec(statement, blockAndTx, true)
	return err
}

// ListOrgEvents lists all events which are not marked as removed
func ListOrgEvents(org string) ([]eth.Event, error) {
	events := []eth.Event{}
	statement := `
		SELECT emittedAt, expiry FROM events
		WHERE removed = $1
		ORDER BY emittedAt DESC
	`
	rows, err := db.Query(statement)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var e eth.Event
	for rows.Next() {
		err = rows.Scan(&e.BlockNumber, &e.Expiry)
		if err != nil {
			return nil, err
		}
		events = append(events, e)
	}
	if err = rows.Err(); err != nil {
		return nil, err
	}
	return events, nil
}

// DeleteOrgEventsBefore deletes all events that happened before emittedAt
func DeleteOrgEventsBefore(org string, emittedAt uint64) error {
	statement := `
		DELETE FROM events
		WHERE org = $1 AND emittedAt < $2
	`
	_, err := db.Exec(statement, org, emittedAt)
	return err
}
