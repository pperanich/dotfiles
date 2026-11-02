package rex

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

// The scanner error is the readiness signal. Startup and formatting of a 1 MiB
// frame can take longer than process teardown, especially in the full/race
// suite; do not start the teardown deadline when Events launches the CLI.
func TestOversizedEventStopsAndReapsPersistentCLI(t *testing.T) {
	testOversizedEventTeardown(t, false)
}

func TestOversizedEventDelayedStartStillReaps(t *testing.T) {
	// This intentional startup hold exceeds the former 600 ms all-in deadline.
	// The marker confirms the child is running; the timer defines the scenario,
	// not readiness for the Scanner assertion below.
	testOversizedEventTeardown(t, true)
}

type oversizedResult struct {
	diagnostics []error
	events      int
}

func testOversizedEventTeardown(t *testing.T, delayed bool) {
	t.Helper()
	dir := t.TempDir()
	pidPath := filepath.Join(dir, "pid")
	readyPath := filepath.Join(dir, "started")
	gatePath := filepath.Join(dir, "release")
	script := "printf '%s' \"$$\" > '" + pidPath + "'\n"
	if delayed {
		script += "printf 'ready' > '" + readyPath + "'\nwhile [ ! -f '" + gatePath + "' ]; do :; done\n"
	}
	// The fake attempts a subsequent valid event, then stays alive. Natural EOF
	// cannot satisfy channel closure; only the Scanner-error teardown can.
	script += "printf '%01048577d\\n' 0\nprintf '%s\\n' '{\"type\":\"session_created\"}'\nwhile :; do :; done\n"
	c := fake(t, script)
	ctx, cancel := context.WithCancel(context.Background())
	ev, errs := c.Events(ctx)
	scanSeen := make(chan struct{})
	finished := make(chan oversizedResult, 1)
	go func() {
		var result oversizedResult
		events, diagnostics := ev, errs
		seen := false
		for events != nil || diagnostics != nil {
			select {
			case _, ok := <-events:
				if !ok {
					events = nil
				} else {
					result.events++
				}
			case e, ok := <-diagnostics:
				if !ok {
					diagnostics = nil
					continue
				}
				result.diagnostics = append(result.diagnostics, e)
				if !seen && strings.Contains(e.Error(), "token too long") {
					seen = true
					close(scanSeen)
				}
			}
		}
		finished <- result
	}()
	// A failing assertion must still cancel and reap the fake CLI and drain the
	// reader; no spinning subprocess or blocked test goroutine may be left over.
	readerDone := false
	defer func() {
		cancel()
		if !readerDone {
			select {
			case <-finished:
			case <-time.After(2 * time.Second):
				t.Error("canceled fake CLI did not close both event channels")
			}
		}
	}()

	if delayed {
		waitForFakeStart(t, readyPath)
		startupHold := time.NewTimer(750 * time.Millisecond)
		<-startupHold.C
		if e := os.WriteFile(gatePath, []byte("go"), 0600); e != nil {
			t.Fatal(e)
		}
	}

	// Separate startup/frame/readiness budget: the clock below does not measure
	// termination, and the fatal Scanner diagnostic must actually be observed.
	var early *oversizedResult
	select {
	case <-scanSeen:
	case result := <-finished:
		readerDone = true
		if !hasScannerFailure(result.diagnostics) {
			t.Fatalf("event stream closed without oversized Scanner diagnostic: %+v", result)
		}
		early = &result // Scanner and channel closure can become ready together.
	case <-time.After(5 * time.Second):
		t.Fatal("oversized Scanner diagnostic never arrived")
	}

	// Only now measure automatic channel closure, without calling cancel.
	var result oversizedResult
	if early != nil {
		result = *early
	} else {
		select {
		case result = <-finished:
			readerDone = true
		case <-time.After(time.Second):
			t.Fatal("Scanner error observed, but persistent CLI/channels did not stop")
		}
	}
	if result.events != 0 {
		t.Fatalf("oversized stream unexpectedly delivered %d events", result.events)
	}
	if !hasScannerFailure(result.diagnostics) {
		t.Fatalf("Scanner failure not retained in diagnostics: %v", result.diagnostics)
	}
	b, e := os.ReadFile(pidPath)
	if e != nil {
		t.Fatal(e)
	}
	pid, e := strconv.Atoi(string(b))
	if e != nil {
		t.Fatal(e)
	}
	if e = syscall.Kill(pid, 0); !errors.Is(e, syscall.ESRCH) {
		t.Fatalf("persistent CLI pid %d not reaped: %v", pid, e)
	}
}

func hasScannerFailure(errs []error) bool {
	for _, e := range errs {
		if strings.Contains(e.Error(), "token too long") {
			return true
		}
	}
	return false
}

func waitForFakeStart(t *testing.T, path string) {
	t.Helper()
	deadline := time.NewTimer(3 * time.Second)
	defer deadline.Stop()
	tick := time.NewTicker(5 * time.Millisecond)
	defer tick.Stop()
	for {
		if _, e := os.Stat(path); e == nil {
			return
		}
		select {
		case <-tick.C:
		case <-deadline.C:
			t.Fatal("fake CLI did not report startup readiness")
		}
	}
}
