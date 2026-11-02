package state

import (
	"context"
	"errors"
	"io"
	"sync/atomic"
	"testing"
	"time"

	"github.com/pperanich/rexpick/internal/rex"
)

func TestRecordsAndLifecycle(t *testing.T) {
	m := New()
	m.ApplySnapshot([]rex.SessionDetail{{ID: "s", Label: "\x1b[31mhello", Windows: []rex.Window{{ID: "w", Blocks: []rex.Block{{ID: "b"}}}}}}, map[BlockKey][]rex.Record{{"s", "b"}: {{State: "idle", Title: "\x1b[31mx"}, {ID: "child", State: "blocked", Message: "\x1b]0;evil\aok"}}})
	a := m.Agents()
	if len(a) != 2 || a[0].RecordID != "child" || a[0].WindowID != "w" || a[0].Message != "ok" || a[1].RecordID != "" || m.Sessions()[0].Label != "hello" {
		t.Fatalf("agents %+v sessions %+v", a, m.Sessions())
	}
	m.Apply(rex.Event{Kind: "program_status_removed", SessionID: "s", BlockID: "b", RemovedIDs: []string{""}})
	if a = m.Agents(); len(a) != 1 || a[0].RecordID != "child" {
		t.Fatalf("removed root %+v", a)
	}
	m.Apply(rex.Event{Kind: "program_status_changed", SessionID: "s", BlockID: "b", RecordID: "child", Record: &rex.Record{State: "novel"}})
	if m.Agents()[0].State != "novel" {
		t.Fatal(m.Agents())
	}
	m.Apply(rex.Event{Kind: "block_closed", SessionID: "s", BlockID: "b"})
	if len(m.Agents()) != 0 {
		t.Fatal(m.Agents())
	}
	m.Apply(rex.Event{Kind: "session_destroyed", SessionID: "s"})
	if len(m.Sessions()) != 0 {
		t.Fatal(m.Sessions())
	}
}

// Reduced copy of the parent's read-only OSC fixture: Rex omits record.id on
// root updates and sends separate expanded IDs for child and root clears.
func TestActualOSCEnvelopeRootChild(t *testing.T) {
	m := New()
	m.ApplySnapshot([]rex.SessionDetail{{ID: "s", Windows: []rex.Window{{ID: "w", Blocks: []rex.Block{{ID: "b"}}}}}}, nil)
	envelope := func(payload string) string {
		return `{"type":"session_event","payload":{"session_id":"s","event":{"type":"block_event","payload":{"block_id":"b","name":` + payload + `}}}}`
	}
	apply := func(raw string) {
		t.Helper()
		ev, e := rex.ParseEvent([]byte(envelope(raw)))
		if e != nil {
			t.Fatal(e)
		}
		m.Apply(ev)
	}
	apply(`"program_status_changed","payload":{"id":"","record":{"state":"working","msg":"Fixture working"}}`)
	apply(`"program_status_changed","payload":{"id":"worker/test","record":{"id":"worker/test","state":"blocked","kind":"question"}}`)
	apply(`"program_status_changed","payload":{"id":"","record":{"state":"idle","msg":"Parent idle; child remains blocked"}}`)
	a := m.Agents()
	if len(a) != 2 || a[0].RecordID != "worker/test" || a[0].State != "blocked" || a[1].RecordID != "" || a[1].State != "idle" {
		t.Fatalf("root/child coexistence %+v", a)
	}
	apply(`"program_status_removed","payload":{"ids":["worker/test"],"reason":"clear"}`)
	a = m.Agents()
	if len(a) != 1 || a[0].RecordID != "" {
		t.Fatalf("child removal %+v", a)
	}
	apply(`"program_status_removed","payload":{"ids":[""],"reason":"clear"}`)
	if len(m.Agents()) != 0 {
		t.Fatalf("root removal %+v", m.Agents())
	}
}
func TestPriorityStable(t *testing.T) {
	m := New()
	m.ApplySnapshot(nil, map[BlockKey][]rex.Record{{"s", "b"}: {{ID: "z", State: "unknown"}, {ID: "a", State: "idle"}, {ID: "c", State: "done"}, {ID: "b", State: "working"}, {ID: "d", State: "blocked"}}})
	got := m.Agents()
	for i, id := range []string{"d", "c", "b", "a", "z"} {
		if got[i].RecordID != id {
			t.Fatal(got)
		}
	}
}

type fakeSource struct{ attempts atomic.Int32 }

func (f *fakeSource) Sessions(context.Context) ([]rex.Session, error) {
	return []rex.Session{{ID: "s"}}, nil
}
func (f *fakeSource) Inspect(context.Context, string) (rex.SessionDetail, error) {
	return rex.SessionDetail{ID: "s", Windows: []rex.Window{{ID: "w", Blocks: []rex.Block{{ID: "b", Creator: "com.superlogical.terminal"}}}}}, nil
}
func (f *fakeSource) Status(context.Context, string, string) ([]rex.Record, error) {
	return []rex.Record{{State: "idle"}}, nil
}
func (f *fakeSource) Events(ctx context.Context) (<-chan rex.Event, <-chan error) {
	attempt := f.attempts.Add(1)
	events := make(chan rex.Event, 1)
	errs := make(chan error, 1)
	if attempt == 1 {
		events <- rex.Event{Kind: "program_status_changed", SessionID: "s", BlockID: "b", Record: &rex.Record{State: "blocked"}}
		close(events)
		errs <- io.EOF
		close(errs)
	} else {
		go func() { <-ctx.Done(); close(events); close(errs) }()
	}
	return events, errs
}
func TestReconnectAndCancel(t *testing.T) {
	src := &fakeSource{}
	m := New()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	notices := make(chan error, 32)
	done := make(chan struct{})
	go func() { Run(ctx, src, m, notices); close(done) }()
	deadline := time.After(700 * time.Millisecond)
	for src.attempts.Load() < 2 {
		select {
		case <-deadline:
			t.Fatal("no reconnect")
		case <-time.After(10 * time.Millisecond):
		}
	}
	// Opening the second subscription precedes its snapshot; wait for that
	// snapshot rather than assuming attempt count implies model publication.
	for {
		a := m.Agents()
		if len(a) == 1 && a[0].State == "idle" {
			break
		}
		select {
		case <-deadline:
			t.Fatalf("reconnected without idle snapshot: %+v", a)
		case <-time.After(time.Millisecond):
		}
	}
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("Run did not stop")
	}
	select {
	case e := <-notices:
		if !errors.Is(e, io.EOF) {
			t.Log(e)
		}
	default:
		t.Fatal("missing disconnect notice")
	}
}
