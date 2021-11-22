// SPDX-License-Identifier: Apache-2.0

package utils

import (
	"radicle-cloud/eth"
	"sync"
)

// EventQueue stores to-be-processed events per org
type EventQueue struct {
	events []eth.Event
	mu     sync.RWMutex
}

// NewEventQueue returns pointer to a new EventQueue
func NewEventQueue(e eth.Event) *EventQueue {
	return &EventQueue{events: []eth.Event{e}}
}

// Len returns number of remaining events
func (eq *EventQueue) Len() int {
	eq.mu.RLock()
	defer eq.mu.RUnlock()
	return len(eq.events)
}

// UnsafeLen returns number of remaining events without locking
func (eq *EventQueue) UnsafeLen() int {
	return len(eq.events)
}

// PeekEvent returns first event without modifying
func (eq *EventQueue) PeekEvent() eth.Event {
	eq.mu.RLock()
	defer eq.mu.RUnlock()
	return eq.events[0]
}

// EatEvent removes first event
func (eq *EventQueue) EatEvent() {
	eq.mu.Lock()
	defer eq.mu.Unlock()
	eq.events = eq.events[1:]
}

// AddEvent adds another event to its array
func (eq *EventQueue) AddEvent(e eth.Event) {
	eq.mu.Lock()
	defer eq.mu.Unlock()
	eq.events = append(eq.events, e)
}

// Lock locks inner lock
func (eq *EventQueue) Lock() {
	eq.mu.Lock()
}

// Unlock unlocks inner lock
func (eq *EventQueue) Unlock() {
	eq.mu.Unlock()
}
