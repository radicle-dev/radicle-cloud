// SPDX-License-Identifier: Apache-2.0

package utils

import (
	"radicle-cloud/db"

	"github.com/emirpasic/gods/trees/binaryheap"
	"github.com/emirpasic/gods/utils"
)

// ExpiryState hold the state for to-be-expired deployments
type ExpiryState struct {
	blockToDeps map[uint64]map[string]db.Dep
	orgToBlock  map[string]uint64
	blocks      *binaryheap.Heap
}

// Init creates the needed maps for ExpiryState
func (s *ExpiryState) Init() *ExpiryState {
	s.blockToDeps = make(map[uint64]map[string]db.Dep)
	s.orgToBlock = make(map[string]uint64)
	s.blocks = binaryheap.NewWith(utils.UInt64Comparator)
	return s
}

func (s *ExpiryState) getDeps(block uint64) (map[string]db.Dep, bool) {
	if orgs, ok := s.blockToDeps[block]; ok {
		return orgs, true
	}
	return nil, false
}

// GetDeps return deps of a block without check
func (s *ExpiryState) GetDeps(block uint64) map[string]db.Dep {
	return s.blockToDeps[block]
}

func (s *ExpiryState) setOrgBlock(org string, block uint64) {
	s.orgToBlock[org] = block
}

func (s *ExpiryState) setBlockToOrgs(block uint64, orgs map[string]db.Dep) {
	s.blockToDeps[block] = orgs
}

func (s *ExpiryState) addDep(dep db.Dep) {
	if orgs, ok := s.getDeps(dep.Expiry); ok {
		// block exists
		orgs[dep.Org] = dep
		s.setOrgBlock(dep.Org, dep.Expiry)
	} else {
		// new block
		// create orgs tree and push org
		orgs := map[string]db.Dep{}
		orgs[dep.Org] = dep
		// set blockToOrgs, set orgToBlock
		s.setBlockToOrgs(dep.Expiry, orgs)
		s.setOrgBlock(dep.Org, dep.Expiry)
		// add block to heap
		s.blocks.Push(dep.Expiry)
	}
}

// AddDeps adds new deps in bulk to a blank state
func (s *ExpiryState) AddDeps(deps []db.Dep) *ExpiryState {
	for _, dep := range deps {
		s.addDep(dep)
	}
	return s
}

// AddOrUpdateDep adds or update a dep on an already created state
func (s *ExpiryState) AddOrUpdateDep(dep db.Dep) {
	if currentOrgBlock, ok := s.orgToBlock[dep.Org]; ok {
		// deployment is already in state
		// remove it from previous orgs and add to new
		delete(s.GetDeps(currentOrgBlock), dep.Org)
		if deps, ok := s.getDeps(dep.Expiry); ok {
			deps[dep.Org] = dep
		} else {
			s.blockToDeps[dep.Expiry] = map[string]db.Dep{
				dep.Org: dep,
			}
			// add new block to heap
			s.blocks.Push(dep.Expiry)
		}
		// change its block to new one
		s.setOrgBlock(dep.Org, dep.Expiry)
	} else {
		// deployment is new
		s.addDep(dep)
	}
}

// Peek returns the smallest block number in heap
func (s *ExpiryState) Peek() (uint64, bool) {
	iblock, ok := s.blocks.Peek()
	if !ok {
		// there's nothing in heap
		return 0, false
	}
	block := iblock.(uint64)
	return block, true
}

// Next cleans up next block and its relevant state
func (s *ExpiryState) Next() {
	block, _ := s.Peek()
	// unset blocks of all orgs in block
	for _, dep := range s.GetDeps(block) {
		delete(s.orgToBlock, dep.Org)
	}
	// remove all deps of block
	delete(s.blockToDeps, block)
	// pop block in heap
	s.blocks.Pop()
}
