// Package state maintains the current Rex session and OSC status snapshot.
package state

import (
	"context"
	"errors"
	"fmt"
	"io"
	"sort"
	"sync"
	"time"

	"github.com/pperanich/rexpick/internal/rex"
)

type BlockKey struct{ SessionID, BlockID string }
type Agent struct{ SessionID, WindowID, BlockID, RecordID, State, Kind, Title, Message string }
type Model struct {
	mu       sync.RWMutex
	sessions map[string]rex.SessionDetail
	records  map[BlockKey]map[string]rex.Record
}

func New() *Model {
	return &Model{sessions: make(map[string]rex.SessionDetail), records: make(map[BlockKey]map[string]rex.Record)}
}
func (m *Model) ApplySnapshot(s []rex.SessionDetail, records map[BlockKey][]rex.Record) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sessions = make(map[string]rex.SessionDetail, len(s))
	m.records = make(map[BlockKey]map[string]rex.Record, len(records))
	for _, v := range s {
		m.sessions[v.ID] = v
	}
	for k, rs := range records {
		m.records[k] = make(map[string]rex.Record)
		for _, r := range rs {
			m.records[k][r.ID] = r
		}
	}
}

// replaceBlockRecords installs one authoritative Rex status query as a unit.
func (m *Model) replaceBlockRecords(k BlockKey, records []rex.Record) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.sessions[k.SessionID]; !ok {
		return
	}
	next := make(map[string]rex.Record, len(records))
	for _, r := range records {
		next[r.ID] = r
	}
	m.records[k] = next
}
func (m *Model) Apply(e rex.Event) {
	m.mu.Lock()
	defer m.mu.Unlock()
	switch e.Kind {
	case "session_destroyed", "session_removed":
		delete(m.sessions, e.SessionID)
		for k := range m.records {
			if k.SessionID == e.SessionID {
				delete(m.records, k)
			}
		}
	case "block_closed", "block_removed":
		delete(m.records, BlockKey{e.SessionID, e.BlockID})
	case "program_status_changed":
		if e.Record == nil {
			return
		}
		k := BlockKey{e.SessionID, e.BlockID}
		if k.SessionID == "" || k.BlockID == "" {
			return
		}
		if m.records[k] == nil {
			m.records[k] = make(map[string]rex.Record)
		}
		r := *e.Record
		r.ID = e.RecordID
		m.records[k][e.RecordID] = r
	case "program_status_removed":
		k := BlockKey{e.SessionID, e.BlockID}
		for _, id := range e.RemovedIDs {
			delete(m.records[k], id)
		}
	}
}
func priority(s string) int {
	switch s {
	case "blocked":
		return 0
	case "done":
		return 1
	case "working":
		return 2
	case "idle":
		return 3
	default:
		return 4
	}
}
func (m *Model) Agents() []Agent {
	m.mu.RLock()
	defer m.mu.RUnlock()
	a := []Agent{}
	for k, rs := range m.records {
		for id, r := range rs {
			v := Agent{SessionID: k.SessionID, BlockID: k.BlockID, RecordID: id, State: r.State, Kind: r.Kind, Title: rex.Sanitize(r.Title), Message: rex.Sanitize(r.Message)}
			for _, w := range m.sessions[k.SessionID].Windows {
				for _, b := range w.Blocks {
					if b.ID == k.BlockID {
						v.WindowID = w.ID
						break
					}
				}
			}
			a = append(a, v)
		}
	}
	sort.Slice(a, func(i, j int) bool {
		p, q := priority(a[i].State), priority(a[j].State)
		if p != q {
			return p < q
		}
		if a[i].SessionID != a[j].SessionID {
			return a[i].SessionID < a[j].SessionID
		}
		if a[i].WindowID != a[j].WindowID {
			return a[i].WindowID < a[j].WindowID
		}
		if a[i].BlockID != a[j].BlockID {
			return a[i].BlockID < a[j].BlockID
		}
		return a[i].RecordID < a[j].RecordID
	})
	return a
}
func (m *Model) Sessions() []rex.Session {
	m.mu.RLock()
	defer m.mu.RUnlock()
	s := make([]rex.Session, 0, len(m.sessions))
	for _, v := range m.sessions {
		s = append(s, rex.Session{ID: v.ID, Label: rex.Sanitize(v.Label)})
	}
	sort.Slice(s, func(i, j int) bool { return s[i].ID < s[j].ID })
	return s
}

// Source is the minimal interface for bootstrap and reconnect.
type Source interface {
	Sessions(context.Context) ([]rex.Session, error)
	Inspect(context.Context, string) (rex.SessionDetail, error)
	Status(context.Context, string, string) ([]rex.Record, error)
	Events(context.Context) (<-chan rex.Event, <-chan error)
}

// Run starts one stream before each snapshot and buffers events while taking
// it. Overlapping status events are reconciled against affected blocks rather
// than blindly replayed; subsequent events are applied live. Errors are sent
// through notices. Rex has no revision/replay token or server ordering barrier,
// so disconnected intervals or in-flight server delivery can still lose updates.
// Run owns its subscriptions and stops them when ctx is canceled.
func Run(ctx context.Context, src Source, m *Model, notices chan<- error) {
	report := func(e error) {
		if e != nil && notices != nil {
			select {
			case notices <- e:
			case <-ctx.Done():
			default:
			}
		}
	}
	delay := 100 * time.Millisecond
	for ctx.Err() == nil {
		streamCtx, cancel := context.WithCancel(ctx)
		events, errs := src.Events(streamCtx)
		// A bounded queue avoids unbounded memory growth while snapshots run. A full
		// queue aborts the snapshot and reconnects rather than silently dropping data.
		buffered := make(chan rex.Event, 4096)
		finished := make(chan error, 1)
		barrier := make(chan chan struct{})
		go func() {
			defer close(buffered)
			for events != nil || errs != nil {
				select {
				case ack := <-barrier:
					close(ack) // all events this reader accepted before the barrier are buffered
				case e, ok := <-events:
					if !ok {
						events = nil
						continue
					}
					select {
					case buffered <- e:
					case <-streamCtx.Done():
						return
					default:
						finished <- errors.New("rex bootstrap event buffer full")
						return
					}
				case e, ok := <-errs:
					if !ok {
						errs = nil
						continue
					}
					if e != nil && e != io.EOF {
						report(e)
					}
				case <-streamCtx.Done():
					return
				}
			}
			finished <- io.EOF
		}()
		snapshotCtx, snapshotCancel := context.WithCancel(streamCtx)
		// Snapshot may finish after EOF; verify stream health before publishing.
		details, records, e := snapshot(snapshotCtx, src)
		snapshotCancel()
		if e == nil {
			select {
			case e = <-finished:
				if e == nil {
					e = io.EOF
				}
			default:
			}
		}
		if e == nil {
			// Synchronize our own stream reader, not the server: this only proves
			// that events already accepted locally are in buffered. Rex supplies
			// no revision token or remote total-order barrier.
			e = streamBarrier(streamCtx, barrier, finished)
		}
		if e == nil {
			m.ApplySnapshot(details, records)
			// Events overlapping a snapshot (including removals) are not safe
			// to replay as authoritative: the snapshot may be newer. Query only
			// the affected blocks; do not poll all terminals or start a new stream.
			dirty := make(map[BlockKey]struct{})
			e = drainOverlap(buffered, finished, m, dirty)
			for rounds := 0; e == nil && len(dirty) > 0; rounds++ {
				if rounds == 3 {
					e = errors.New("rex status changed throughout bounded reconciliation")
					break
				}
				pending := dirty
				dirty = make(map[BlockKey]struct{})
				for key := range pending {
					var rs []rex.Record
					rs, e = src.Status(streamCtx, key.SessionID, key.BlockID)
					if e != nil {
						break
					}
					m.replaceBlockRecords(key, rs)
					// A new event accepted during Status can describe an earlier
					// state than this query. Reconcile it again rather than apply it.
					e = streamBarrier(streamCtx, barrier, finished)
					if e != nil {
						break
					}
					e = drainOverlap(buffered, finished, m, dirty)
					if e != nil {
						break
					}
				}
			}
			for e == nil {
				select {
				case ev, ok := <-buffered:
					if !ok {
						e = io.EOF
						break
					}
					m.Apply(ev)
					switch ev.Kind {
					case "session_created", "block_created", "session_view_changed", "window_created", "window_closed":
						e = errors.New("rex layout changed")
					}
				case e = <-finished:
					if e == nil {
						e = io.EOF
					}
				case <-ctx.Done():
					e = ctx.Err()
				}
			}
		}
		cancel()
		if ctx.Err() != nil {
			return
		}
		if e != nil {
			report(fmt.Errorf("rex state stale; resnapshotting: %w", e))
		}
		timer := time.NewTimer(delay)
		select {
		case <-timer.C:
		case <-ctx.Done():
			timer.Stop()
			return
		}
		if delay < 2*time.Second {
			delay *= 2
		}
	}
}

// streamBarrier flushes only our local forwarding goroutine. It is not a Rex
// server ordering guarantee and cannot close gaps across disconnects.
func streamBarrier(ctx context.Context, barrier chan chan struct{}, finished <-chan error) error {
	ack := make(chan struct{})
	select {
	case barrier <- ack:
	case e := <-finished:
		if e == nil {
			return io.EOF
		}
		return e
	case <-ctx.Done():
		return ctx.Err()
	}
	select {
	case <-ack:
		return nil
	case e := <-finished:
		if e == nil {
			return io.EOF
		}
		return e
	case <-ctx.Done():
		return ctx.Err()
	}
}

// drainOverlap marks only status-bearing blocks for a fresh query. Buffered
// updates/removals might precede a newer snapshot, so applying them first
// would incorrectly resurrect deleted records or roll back completed work.
func drainOverlap(buffered <-chan rex.Event, finished <-chan error, m *Model, dirty map[BlockKey]struct{}) error {
	for n := 0; n < cap(buffered); n++ {
		select {
		case e := <-finished:
			if e == nil {
				return io.EOF
			}
			return e
		case ev, ok := <-buffered:
			if !ok {
				return io.EOF
			}
			switch ev.Kind {
			case "program_status_changed", "program_status_removed":
				if ev.SessionID != "" && ev.BlockID != "" {
					dirty[BlockKey{ev.SessionID, ev.BlockID}] = struct{}{}
				}
			default:
				m.Apply(ev)
				switch ev.Kind {
				case "session_created", "block_created", "session_view_changed", "window_created", "window_closed":
					return errors.New("rex layout changed")
				}
			}
		default:
			return nil
		}
	}
	return errors.New("rex bootstrap event buffer drain limit exceeded")
}
func snapshot(ctx context.Context, src Source) ([]rex.SessionDetail, map[BlockKey][]rex.Record, error) {
	list, e := src.Sessions(ctx)
	if e != nil {
		return nil, nil, e
	}
	details := make([]rex.SessionDetail, 0, len(list))
	records := make(map[BlockKey][]rex.Record)
	for _, s := range list {
		d, err := src.Inspect(ctx, s.ID)
		if err != nil {
			return nil, nil, err
		}
		details = append(details, d)
		for _, w := range d.Windows {
			for _, b := range w.Blocks {
				if b.Creator != "com.superlogical.terminal" {
					continue
				}
				rs, err := src.Status(ctx, d.ID, b.ID)
				if err != nil {
					return nil, nil, err
				}
				records[BlockKey{d.ID, b.ID}] = rs
			}
		}
	}
	return details, records, nil
}
