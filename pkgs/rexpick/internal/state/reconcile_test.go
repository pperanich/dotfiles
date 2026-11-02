package state

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	"github.com/pperanich/rexpick/internal/rex"
)

// All event channels are synthetic. The fake emits before Sessions finishes so
// the subscription event overlaps the snapshot, not an ordinary later update.
type overlapSource struct {
	events   chan rex.Event
	sent     chan struct{}
	calls    atomic.Int32
	snapshot []rex.Record
	current  []rex.Record
	initial  *rex.Event
	during   *rex.Event
}

func (s *overlapSource) Events(ctx context.Context) (<-chan rex.Event, <-chan error) {
	s.events = make(chan rex.Event)
	s.sent = make(chan struct{})
	errs := make(chan error)
	go func() {
		initial := rex.Event{Kind: "program_status_changed", SessionID: "s", BlockID: "b", Record: &rex.Record{State: "working"}}
		if s.initial != nil {
			initial = *s.initial
		}
		s.events <- initial
		close(s.sent)
		<-ctx.Done()
		close(s.events)
		close(errs)
	}()
	return s.events, errs
}
func (s *overlapSource) Sessions(ctx context.Context) ([]rex.Session, error) {
	select {
	case <-s.sent:
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	return []rex.Session{{ID: "s"}}, nil
}
func (s *overlapSource) Inspect(context.Context, string) (rex.SessionDetail, error) {
	return rex.SessionDetail{ID: "s", Windows: []rex.Window{{ID: "w", Blocks: []rex.Block{{ID: "b", Creator: "com.superlogical.terminal"}}}}}, nil
}
func (s *overlapSource) Status(ctx context.Context, _, _ string) ([]rex.Record, error) {
	call := s.calls.Add(1)
	if call == 2 && s.during != nil {
		select {
		case s.events <- *s.during:
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
	if call == 1 {
		return s.snapshot, nil
	}
	return s.current, nil
}
func TestBufferedStatusOlderThanSnapshot(t *testing.T) {
	src := &overlapSource{snapshot: []rex.Record{{State: "done"}}, current: []rex.Record{{State: "done"}}}
	runOverlap(t, src, "done", 2)
}
func TestBufferedRemovalOlderThanSnapshot(t *testing.T) {
	src := &overlapSource{snapshot: []rex.Record{{State: "done"}, {ID: "child", State: "blocked"}}, current: []rex.Record{{State: "done"}, {ID: "child", State: "blocked"}}}
	src.initial = &rex.Event{Kind: "program_status_removed", SessionID: "s", BlockID: "b", RemovedIDs: []string{"", "child"}}
	agents := runOverlap(t, src, "done", 2)
	// Both records survive the older removal; they came from the later snapshot.
	if len(agents) != 2 || agents[0].RecordID != "child" || agents[1].RecordID != "" {
		t.Fatalf("older removal replaced newer snapshot: %+v", agents)
	}

}
func TestEventDuringReconciliation(t *testing.T) {
	src := &overlapSource{snapshot: []rex.Record{{State: "done"}}, current: []rex.Record{{State: "done"}}}
	src.during = &rex.Event{Kind: "program_status_changed", SessionID: "s", BlockID: "b", Record: &rex.Record{State: "working"}}
	runOverlap(t, src, "done", 3)
}
func runOverlap(t *testing.T, src *overlapSource, want string, minCalls int32) []Agent {
	t.Helper()
	m := New()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { Run(ctx, src, m, make(chan error, 16)); close(done) }()
	defer func() {
		cancel()
		select {
		case <-done:
		case <-time.After(time.Second):
			t.Fatal("Run did not stop")
		}
	}()
	deadline := time.After(time.Second)
	for {
		a := m.Agents()
		if src.calls.Load() >= minCalls && len(a) > 0 && a[len(a)-1].State == want {
			return a
		}
		select {
		case <-deadline:
			t.Fatalf("state=%+v status calls=%d; wanted %s after %d calls", a, src.calls.Load(), want, minCalls)
		case <-time.After(time.Millisecond):
		}
	}
}
