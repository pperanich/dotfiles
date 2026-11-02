package rex

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestEventsNoisyStderrBounded(t *testing.T) {
	// The fake writes over 2 MiB; returned diagnostics must be capped like the
	// short-lived CLI calls, not retained for the stream's lifetime.
	c := fake(t, `i=0; while [ "$i" -lt 300 ]; do printf '%08192d' 0 >&2; i=$((i+1)); done; exit 42`)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	events, errs := c.Events(ctx)
	for range events {
	}
	var got error
	for e := range errs {
		if e != io.EOF {
			got = e
		}
	}
	if got == nil || !strings.Contains(got.Error(), "exit status 42") {
		t.Fatalf("missing CLI failure: %v", got)
	}
	if len(got.Error()) > 9000 {
		t.Fatalf("unbounded persistent stderr: %d bytes", len(got.Error()))
	}
}

func TestEventsNoisyStderrCancellationReaps(t *testing.T) {
	pidFile := filepath.Join(t.TempDir(), "pid")
	c := fake(t, "printf '%s' \"$$\" > '"+pidFile+"'\nprintf '%s\\n' '{\"type\":\"session_created\"}'\nwhile :; do printf '%08192d' 0 >&2; done\n")
	ctx, cancel := context.WithCancel(context.Background())
	events, errs := c.Events(ctx)
	select {
	case _, ok := <-events:
		if !ok {
			cancel()
			t.Fatal("fake event stream closed early")
		}
	case <-time.After(2 * time.Second):
		cancel()
		t.Fatal("fake event not delivered")
	}
	data, e := os.ReadFile(pidFile)
	if e != nil {
		cancel()
		t.Fatal(e)
	}
	pid, e := strconv.Atoi(string(data))
	if e != nil {
		cancel()
		t.Fatal(e)
	}
	cancel()
	done := make(chan struct{})
	go func() {
		for range events {
		}
		for range errs {
		}
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("stream did not stop/reap on cancellation")
	}
	if e = syscall.Kill(pid, 0); !errors.Is(e, syscall.ESRCH) {
		t.Fatalf("fake CLI process %d not reaped: %v", pid, e)
	}
}
