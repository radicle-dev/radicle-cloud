// SPDX-License-Identifier: Apache-2.0

package eth

import (
	"context"
	"encoding/binary"
	"fmt"
	"log"
	"math/big"
	"os"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

var newTopUpHash common.Hash
var deploymentStoppedHash common.Hash
var l *log.Logger
var c chan Event

type EventType uint8

const (
	TopUpEvent EventType = iota
	DeploymentStoppedEvent
)

func init() {
	l = log.New(os.Stderr, "[ETH]	", log.Ldate|log.Ltime|log.Lshortfile)
	newTopUpHash = crypto.Keccak256Hash([]byte("NewTopUp(address,uint64)"))
	deploymentStoppedHash = crypto.Keccak256Hash([]byte("DeploymentStopped(address,uint64)"))
}

// Event is what we emit to main on each purchase
type Event struct {
	Org         string
	Expiry      uint64
	BlockNumber uint64
	BlockAndTx  []byte
	Removed     bool
	Type        EventType
}

/*
// StartListening listens for purchase events on chain
func startListening(c chan Event, from *big.Int) {
	for {
		time.Sleep(5 * time.Second)
		c <- Event{"0xceaa01bd5a428d2910c82bbefe1bc7a8cc6207d9", 888888888, 0x01}
		time.Sleep(888888888 * time.Second)
	}
}
*/

// StartListening listens for contract events from chain
func StartListening(ec chan Event, from *big.Int) {
	c = ec
	var err error
	client, err := ethclient.Dial(os.Getenv("CONTRACT_L2_WSS"))
	if err != nil {
		l.Fatal(err)
	}

	contractAddress := common.HexToAddress(os.Getenv("CONTRACT_ADDRESS"))
	query := ethereum.FilterQuery{
		FromBlock: from,
		Addresses: []common.Address{contractAddress},
	}

	// handle historic events
	history, err := client.FilterLogs(context.Background(), query)
	if err != nil {
		l.Fatal(err)
	}
	for _, h := range history {
		handleLog(h)
	}

	// subscribe to new events
	logs := make(chan types.Log)
	sub, err := client.SubscribeFilterLogs(context.Background(), query, logs)
	if err != nil {
		l.Fatal(err)
	}

	for {
		select {
		case err := <-sub.Err():
			// e.g. "i/o timeout" error which happens after 5 min idle
			l.Println("Subscription error", err)
			return
		case log := <-logs:
			handleLog(log)
		}
	}
}

// UpdateCurrentBlock periodically updates the passed integer to latest block
func UpdateCurrentBlock(current *uint64) {
	client, err := ethclient.Dial(os.Getenv("CONTRACT_L1_WSS"))
	if err != nil {
		l.Fatal(err)
	}
	for {
		header, err := client.HeaderByNumber(context.Background(), nil)
		if err != nil {
			l.Fatal(err)
		}

		*current = header.Number.Uint64()
		l.Println("Current block is at", *current)
		time.Sleep(time.Second * 5 * 60)
	}
}

func handleLog(log types.Log) {
	switch log.Topics[0] {
	case newTopUpHash:
		handleNewTopUpLog(log)
	case deploymentStoppedHash:
		handleDeploymentStopped(log)
	}
}

func handleNewTopUpLog(log types.Log) {
	org := fmt.Sprintf("0x%x", log.Data[12:32])      // 0  - 32 -- last 20 bytes
	expiry := binary.BigEndian.Uint64(log.Data[56:]) // 32 - 64 -- last  8 bytes

	l.Printf(
		"NewTopUp for org=%s expiry=%d emittedAt=%d\n",
		org, expiry, log.BlockNumber,
	)
	c <- Event{
		Org:         org,
		Expiry:      expiry,
		BlockNumber: log.BlockNumber,
		BlockAndTx:  append(log.BlockHash[:], log.TxHash[:]...),
		Removed:     log.Removed,
		Type:        TopUpEvent,
	}
}

func handleDeploymentStopped(log types.Log) {
	org := fmt.Sprintf("0x%x", log.Data[12:32])
	expiry := binary.BigEndian.Uint64(log.Data[56:])

	l.Printf(
		"DeploymentStopped for org=%s expiry=%d emittedAt=%d\n",
		org, expiry, log.BlockNumber,
	)
	c <- Event{
		Org:         org,
		Expiry:      expiry,
		BlockNumber: log.BlockNumber,
		BlockAndTx:  append(log.BlockHash[:], log.TxHash[:]...),
		Removed:     log.Removed,
		Type:        DeploymentStoppedEvent,
	}
}

func (et *EventType) String() string {
	switch *et {
	case TopUpEvent:
		return "NewTopUp"
	case DeploymentStoppedEvent:
		return "DeploymentStopped"
	default:
		return ""
	}
}
