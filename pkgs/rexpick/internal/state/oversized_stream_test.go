package state

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/pperanich/rexpick/internal/rex"
)

func TestOversizedPersistentStreamResubscribesAndRecovers(t *testing.T) {
	dir := t.TempDir()
	countPath := filepath.Join(dir, "attempts")
	gatePath := filepath.Join(dir, "release-second-event")
	firstPID := filepath.Join(dir, "first-pid")
	executable := filepath.Join(dir, "rex")
	script := fmt.Sprintf(`#!/bin/sh
countFile=%s
gateFile=%s
firstPID=%s
case "$*" in
 *"events --all --json")
   if [ -f "$countFile" ]; then read n < "$countFile"; else n=0; fi
   n=$((n+1)); printf '%%s' "$n" > "$countFile"
   if [ "$n" -eq 1 ]; then
     printf '%%s' "$$" > "$firstPID"
     printf '%%01048577d\n' 0
     printf '%%s\n' '{"type":"session_created"}'
   else
     while [ ! -f "$gateFile" ]; do :; done
     printf '%%s\n' '{"type":"session_event","payload":{"session_id":"s","event":{"type":"block_event","payload":{"block_id":"b","name":"program_status_changed","payload":{"id":"","record":{"state":"blocked"}}}}}}'
   fi
   while :; do :; done ;;
 *"ls --json") printf '%%s' '{"sessions":[{"session_id":"s"}]}' ;;
 *"session inspect"*)
   label=first
   if [ -f "$countFile" ]; then read n < "$countFile"; if [ "$n" -ge 2 ]; then label=after-resubscribe; fi; fi
   printf '{"session_id":"s","label":"%%s","windows":[{"window_id":"w","layers":[{"blocks":[{"block_id":"b","creator_name":"com.superlogical.terminal"}]}]}]}' "$label" ;;
 *"program_status") printf '%%s' '{"records":[{"state":"idle"}]}' ;;
 *" process") printf '%%s' '{"foreground":null}' ;;
 *" pwd") printf '%%s' '{}' ;;
 *) exit 2 ;;
esac
`, strconv.Quote(countPath), strconv.Quote(gatePath), strconv.Quote(firstPID))
	if e := os.WriteFile(executable, []byte(script), 0700); e != nil {
		t.Fatal(e)
	}
	c, e := rex.New(rex.Config{Executable: executable, Timeout: time.Second})
	if e != nil {
		t.Fatal(e)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	notices := make(chan error, 32)
	m := New()
	go func() { Run(ctx, c, m, notices); close(done) }()
	defer func() {
		cancel()
		select {
		case <-done:
		case <-time.After(2 * time.Second):
			t.Error("state.Run did not stop and reap subprocess")
		}
	}()
	deadline := time.After(2 * time.Second)
	for {
		ss := m.Sessions()
		if len(ss) == 1 && ss[0].Label == "after-resubscribe" {
			break
		}
		select {
		case <-deadline:
			t.Fatalf("stream never resubscribed after scanner failure; sessions=%+v notices=%v", ss, drainNotices(notices))
		case <-time.After(time.Millisecond):
		}
	}
	if e := os.WriteFile(gatePath, []byte("release"), 0600); e != nil {
		t.Fatal(e)
	}
	deadline = time.After(time.Second)
	for {
		agents := m.Agents()
		if len(agents) == 1 && agents[0].State == "blocked" {
			break
		}
		select {
		case <-deadline:
			t.Fatalf("valid event on recovered subscription not applied: %+v", agents)
		case <-time.After(time.Millisecond):
		}
	}
	hasScan, hasStale := false, false
	for _, e := range drainNotices(notices) {
		hasScan = hasScan || strings.Contains(e.Error(), "token too long")
		hasStale = hasStale || strings.Contains(e.Error(), "stale")
	}
	if !hasScan || !hasStale {
		t.Fatalf("missing scanner/stale diagnostics (scan=%v stale=%v)", hasScan, hasStale)
	}
	b, e := os.ReadFile(firstPID)
	if e != nil {
		t.Fatal(e)
	}
	pid, e := strconv.Atoi(string(b))
	if e != nil {
		t.Fatal(e)
	}
	if e = syscall.Kill(pid, 0); !errors.Is(e, syscall.ESRCH) {
		t.Fatalf("first CLI pid %d not reaped before resubscription: %v", pid, e)
	}
}
func drainNotices(ch <-chan error) []error {
	var errors []error
	for {
		select {
		case e := <-ch:
			errors = append(errors, e)
		default:
			return errors
		}
	}
}
