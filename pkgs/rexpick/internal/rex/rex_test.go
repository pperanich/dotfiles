package rex

import (
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func fake(t *testing.T, script string) *Client {
	t.Helper()
	p := filepath.Join(t.TempDir(), "rex")
	if e := os.WriteFile(p, []byte("#!/bin/sh\n"+script), 0700); e != nil {
		t.Fatal(e)
	}
	c, e := New(Config{Executable: p, ClientID: "client:test", Timeout: time.Second})
	if e != nil {
		t.Fatal(e)
	}
	return c
}
func TestCommands(t *testing.T) {
	c := fake(t, `case "$*" in
 *"ls --json") printf '{"sessions":[{"session_id":"s1","label":"one"}]}' ;;
 *"session inspect"*) printf '{"session_id":"s1","windows":[{"window_id":"w1","layers":[{"blocks":[{"block_id":"b1","creator_name":"com.superlogical.terminal"}]}]}]}' ;;
 *"program_status") printf '{"records":[{"state":"blocked","msg":"hello"}]}' ;;
 *"capture "*) printf '\033[31mhello\033[0m\n' ;;
 *"new "*) printf '{"session_id":"s2","initial_windows":[{"window_id":"w2","block_ids":["b2"]}]}' ;;
 *) exit 3;; esac`)
	ctx := context.Background()
	s, e := c.Sessions(ctx)
	if e != nil || len(s) != 1 || s[0].ID != "s1" {
		t.Fatalf("sessions %v %v", s, e)
	}
	d, e := c.Inspect(ctx, "s1")
	if e != nil || len(d.Windows[0].Blocks) != 1 {
		t.Fatalf("inspect %v %v", d, e)
	}
	r, e := c.Status(ctx, "s1", "b1")
	if e != nil || len(r) != 1 {
		t.Fatalf("status %v %v", r, e)
	}
	v, e := c.Capture(ctx, "s1", "b1")
	if e != nil || v != "hello\n" {
		t.Fatalf("capture %q %v", v, e)
	}
	d, e = c.NewSession(ctx, "name", "/tmp/a space")
	if e != nil || d.ID != "s2" || d.Windows[0].Blocks[0].ID != "b2" {
		t.Fatalf("new %v %v", d, e)
	}
}
func TestCancellation(t *testing.T) {
	c := fake(t, "sleep 10")
	c.config.Timeout = 20 * time.Millisecond
	_, e := c.Sessions(context.Background())
	if !errors.Is(e, context.DeadlineExceeded) {
		t.Fatal(e)
	}
	ctx, cancel := context.WithCancel(context.Background())
	ev, errs := c.Events(ctx)
	cancel()
	for range ev {
	}
	for range errs {
	}
}
func TestEvents(t *testing.T) {
	c := fake(t, `printf '%s\n' '{bad' '{"type":"session_event","payload":{"session_id":"s","event":{"type":"block_event","payload":{"block_id":"b","name":"program_status_changed","payload":{"id":"","record":{"state":"blocked"}}}}}}'`)
	ev, errs := c.Events(context.Background())
	var got []Event
	for x := range ev {
		got = append(got, x)
	}
	malformed, eof := false, false
	for e := range errs {
		if errors.Is(e, io.EOF) {
			eof = true
		} else if e != nil {
			malformed = true
		}
	}
	if len(got) != 1 || got[0].Kind != "program_status_changed" || got[0].SessionID != "s" || got[0].Record == nil || !malformed || !eof {
		t.Fatalf("events %+v malformed=%v eof=%v", got, malformed, eof)
	}
}
func TestSanitize(t *testing.T) {
	v := Sanitize("a\x1b]8;;evil\aB\x1b[31mC\x1b[0m\x1b]0;bad\x1b\\\x00\x9b31mZ\n")
	if strings.ContainsAny(v, "\x1b\x00") || v != "aBCZ\n" {
		t.Fatalf("sanitized %q", v)
	}
}
