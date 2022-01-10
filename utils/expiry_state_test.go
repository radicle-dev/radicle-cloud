// SPDX-License-Identifier: Apache-2.0

package utils

import (
	"radicle-cloud/db"
	"testing"
)

func logDeps(t *testing.T, s *ExpiryState) {
	t.Log(100, s.GetDeps(100))
	t.Log(150, s.GetDeps(150))
	t.Log(250, s.GetDeps(250))
	t.Log(350, s.GetDeps(350))
	t.Log()
}

func logHeap(t *testing.T, s *ExpiryState) {
	t.Log("heap:", s.blocks)
	t.Log()
}

func logOrgs(t *testing.T, s *ExpiryState) {
	t.Log("orgToBlock:", s.orgToBlock)
	t.Log()
}

func TestExpiryState(t *testing.T) {
	deps := []db.Dep{
		{Org: "0x1", Expiry: 150, Provider: ""},
		{Org: "0x2", Expiry: 250, Provider: ""},
		{Org: "0x3", Expiry: 350, Provider: ""},
	}
	s := new(ExpiryState).Init().AddDeps(deps)
	logDeps(t, s)
	logHeap(t, s)
	logOrgs(t, s)

	block, _ := s.Peek()
	if block != 150 {
		t.Errorf("Expected: %d, Actual: %d\n", 150, block)
	}

	s.AddOrUpdateDep(db.Dep{Org: "0x1", Expiry: 100, Provider: ""})
	logDeps(t, s)
	logHeap(t, s)
	logOrgs(t, s)
	block, _ = s.Peek()
	if block != 100 {
		t.Errorf("Expected: %d, Actual: %d\n", 100, block)
	}
	if _, ok := s.GetDeps(100)["0x1"]; !ok {
		t.Error("Expected: 0x1 to be at 100")
	}

	s.AddOrUpdateDep(db.Dep{Org: "0x1", Expiry: 250, Provider: ""})
	logDeps(t, s)
	logHeap(t, s)
	logOrgs(t, s)
	if _, ok := s.GetDeps(250)["0x1"]; !ok {
		t.Error("Expected: 0x1 to be at 250")
	}

	s.Next()
	logHeap(t, s)
	s.Next()
	logHeap(t, s)
	block, _ = s.Peek()
	if block != 250 {
		t.Errorf("Expected: %d, Actual: %d\n", 250, block)
	}

	s.AddOrUpdateDep(db.Dep{Org: "0x5", Expiry: 500, Provider: ""})
	t.Log(500, s.GetDeps(500))
	logHeap(t, s)
	logOrgs(t, s)
	if _, ok := s.GetDeps(500)["0x5"]; !ok {
		t.Error("Expected: 0x5 to be at 500")
	}
}
