// SPDX-License-Identifier: Apache-2.0

package main

import (
	"log"
	"math/big"
	"os"
	"radicle-cloud/cloud"
	"radicle-cloud/db"
	"radicle-cloud/eth"
	"radicle-cloud/utils"
	"sync"
	"time"

	"github.com/joho/godotenv"
)

var l *log.Logger

// queue(s) to be processed for each org
var queues sync.Map

func init() {
	l = log.New(os.Stderr, "[MAIN]	", log.Ldate|log.Ltime|log.Lshortfile)
	setup()
}

func main() {
	var currentBlock uint64 = 0
	go eth.UpdateCurrentBlock(&currentBlock)
	for currentBlock == 0 {
		l.Println("Initializing current block")
		time.Sleep(time.Second)
	}

	ethEvents := make(chan eth.Event)
	stateEvents := make(chan db.Dep)
	go runEthListener(ethEvents, &currentBlock)
	go terminateExpiringOrgs(stateEvents, &currentBlock)

	for {
		// stream events from contract
		e := <-ethEvents

		if err := db.UpsertEvent(e); err != nil {
			l.Fatal("Failed to upsert event", e, err)
		}

		// if event has been removed, a reorg has happened
		if e.Removed {
			stateAfterRemoval(&e, &currentBlock)
		}

		if queue, ok := queues.LoadOrStore(e.Org, utils.NewEventQueue(e)); ok {
			// queue already exists, and a goroutine is running, just add event
			q := queue.(*utils.EventQueue)
			q.AddEvent(e)
			// between LoadOrStore and AddEvent, queue might get deleted from map
			if _, ok := queues.LoadOrStore(e.Org, q); !ok {
				// re-spawn another goroutine for this org
				go processEventsForOrg(e.Org, stateEvents)
			}
		} else {
			// spawn a goroutine to process newly created queue
			go processEventsForOrg(e.Org, stateEvents)
		}
	}
}

func processEventsForOrg(org string, stateEvents chan db.Dep) {
	queue, ok := queues.Load(org)
	if !ok {
		l.Fatal("Queue was missing for org", org)
	}
	q := queue.(*utils.EventQueue)

	tries := 0
	for {
		if q.Len() == 0 {
			// lock and check again
			q.Lock()
			if q.UnsafeLen() == 0 {
				// all done, take out org from queues
				queues.Delete(org)
				q.Unlock()
				break
			}
			q.Unlock()
		}
		if processEvent(q.PeekEvent(), stateEvents) {
			q.EatEvent()
			tries = 0
		} else {
			tries++
			if tries == 3 {
				l.Fatalf("Failed to process event %+v after 3 tries\n", q.PeekEvent())
			}
			// sleep 15s and try again
			time.Sleep(time.Second * 15)
		}
	}
}

func processEvent(e eth.Event, stateEvents chan db.Dep) bool {
	l.Printf("Processing: %+v\n", e)

	if e.Type == eth.DeploymentStoppedEvent {
		provider, err := db.GetProvider(e.Org)
		if err != nil {
			l.Fatal("Failed to get provider for org", e.Org, err)
		}
		stateEvents <- db.Dep{Org: e.Org, Expiry: e.Expiry, Provider: provider}
		return true
	}

	// upsert deployment, update expiry if already exists
	provider, ip, status, err := db.UpsertDep(e)
	if err != nil {
		l.Fatal("Error upserting org", e.Org, err)
	}
	if status == db.RunningStatus && provider != "" {
		// org existed, updated expiry, and we can exit
		stateEvents <- db.Dep{Org: e.Org, Expiry: e.Expiry, Provider: provider}
		return true
	}

	switch status {
	// case db.InitialStatus:
	// straight ahead
	case db.AllocatedStatus:
		goto ALLOCATED
	case db.SetupFailedStatus:
		goto SETUP
	case db.RunningStatus:
		goto RUNNING
	}

	// reserve a server
	provider, ip, err = cloud.ReserveServer(e.Org)
	if err != nil {
		l.Println("Couldn't reserve server", err)
		return false
	}

	// update ip and provider for deployment and set status to allocated
	if err = db.UpdateOrgServer(e.Org, ip, provider); err != nil {
		l.Println("Failed updating ip for org", e.Org, err)
		return false
	}

ALLOCATED:
	// create dns record for org subdomain
	if err = cloud.CreateDNS(e.Org, ip); err != nil {
		if err.Error() != "HTTP status 400: Record already exists. (81057)" {
			l.Println("Failed to create dns record for org", e.Org, err)
			return false
		}
	}

SETUP:
RUNNING:
	if status != db.RunningStatus {
		// run ansible for initial setup
		err = cloud.RunAnsible(e.Org, ip, 10)
	} else {
		// ansible already configured this
		err = nil
	}
	if err != nil {
		// failed after 10 retries
		l.Println("Failed to complete configuration after 10 tries for", e.Org, ip, err)
		if err = db.SetStatus(e.Org, "setup-failed"); err != nil {
			l.Println("Failed to set status to 'setup-failed' for", e.Org, ip, err)
		}
	} else {
		l.Println("Configured org", e.Org, "with ip", ip)
		// flip status to runnning
		if err = db.SetStatus(e.Org, "running"); err != nil {
			l.Println("Failed to set status to 'running' for", e.Org, ip, err)
		} else {
			l.Printf("Org %s status set to 'running' in DB", e.Org)
			stateEvents <- db.Dep{Org: e.Org, Expiry: e.Expiry, Provider: provider}
			if err = db.MarkEventProcessed(e.BlockAndTx); err != nil {
				return true
			}
			return false
		}
	}
	return false
}

func setup() {
	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file", err)
	}

	db.Setup()
	cloud.Setup()
}

func getLastProcessedBlock(current *uint64) *big.Int {
	var last big.Int
	lastProcessed, err := db.GetLastProcessedBlock()
	if err != nil {
		l.Println("Error getting last processed block", err)
		last.SetUint64(*current)
	}
	last.SetUint64(lastProcessed)
	return &last
}

func runEthListener(ec chan eth.Event, currentBlock *uint64) {
	for {
		eth.StartListening(ec, getLastProcessedBlock(currentBlock))
		time.Sleep(time.Second * 5)
	}
}

func terminateExpiringOrgs(c chan db.Dep, currentBlock *uint64) {
	// list all deployments with ascending expiring date
	deps, err := db.ListDeployments()
	if err != nil {
		l.Fatal("Can't list Deployments", err)
	}
	s := new(utils.ExpiryState).Init().AddDeps(deps)

	for {
		// more than an event can be in a block so loop through all of them
		for {
			// take a peek to check if smallest block in heap has expired
			block, ok := s.Peek()
			if !ok {
				// break out of loop if there's nothing
				break
			}
			if block <= *currentBlock {
				for _, dep := range s.GetDeps(block) {
					l.Printf("Deployment for org=%s has expired\n", dep.Org)
					if cloud.TerminateOrg(dep.Org, dep.Provider) {
						l.Println("Cloud resource was terminated for", dep.Org, "in", dep.Provider)
					}
					if err := db.DeleteOrg(dep.Org); err != nil {
						time.Sleep(5 * time.Second)
						l.Fatalf("Failed to delete org=%s provider=%s err=%v\n", dep.Org, dep.Provider, err)
					}
				}
				s.Next() // clean up
			} else {
				// min of heap is still higher than current block
				break
			}
		}

		nextAwake := 3600 * time.Second
		if block, ok := s.Peek(); ok {
			nextAwake = time.Duration((block-*currentBlock)*14) * time.Second
		}

		select {
		// sleep until next org expires
		case <-time.After(nextAwake):
		// or a new event happens
		case e := <-c:
			s.AddOrUpdateDep(e)
		}
	}
}

func stateAfterRemoval(e *eth.Event, currentBlock *uint64) {
	events, err := db.ListOrgEvents(e.Org)
	if err != nil {
		l.Fatal("Error processing removal for org", e.Org, err)
	}

	if len(events) > 0 {
		event := events[0]
		// if expiry is still valid, this is the latest state
		if event.Expiry > *currentBlock {
			// swap expiry with last valid state
			e.Expiry = event.Expiry
			// if this event is confirmed, remove other events before it
			if event.BlockNumber+9 <= *currentBlock {
				if err := db.DeleteOrgEventsBefore(e.Org, event.BlockNumber); err != nil {
					l.Println("Failed to delete events before", event.BlockNumber, "for", e.Org)
				}
			}
			return
		}
	}
	// no events means deployment should be removed
	e.Type = eth.DeploymentStoppedEvent
	e.Expiry = *currentBlock
}
