package ui

import (
	"context"
	"errors"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/pperanich/rexpick/internal/projects"
	"github.com/pperanich/rexpick/internal/rex"
	"github.com/pperanich/rexpick/internal/state"
)

type fake struct {
	details           []rex.SessionDetail
	captures          map[string]string
	selected, focused string
	created           int
	err               error
}

func (f *fake) Sessions(context.Context) ([]rex.Session, error) {
	s := []rex.Session{}
	for _, d := range f.details {
		s = append(s, rex.Session{ID: d.ID, Label: d.Label})
	}
	return s, f.err
}
func (f *fake) Inspect(_ context.Context, id string) (rex.SessionDetail, error) {
	for _, d := range f.details {
		if d.ID == id {
			return d, nil
		}
	}
	return rex.SessionDetail{}, errors.New("missing session")
}
func (f *fake) Status(context.Context, string, string) ([]rex.Record, error) { return nil, nil }
func (f *fake) Events(context.Context) (<-chan rex.Event, <-chan error) {
	return make(chan rex.Event), make(chan error)
}
func (f *fake) Capture(_ context.Context, _, block string) (string, error) {
	return f.captures[block], nil
}
func (f *fake) NewSession(_ context.Context, _, cwd string) (rex.SessionDetail, error) {
	f.created++
	return rex.SessionDetail{ID: "created", ActiveWindowID: "new-window"}, nil
}
func (f *fake) Select(_ context.Context, s, w string) error     { f.selected = s + "/" + w; return f.err }
func (f *fake) FocusBlock(_ context.Context, s, b string) error { f.focused = s + "/" + b; return nil }
func base() (Model, *fake) {
	f := &fake{}
	s := state.New()
	s.ApplySnapshot([]rex.SessionDetail{{ID: "one", Label: "First", ActiveWindowID: "w1", Windows: []rex.Window{{ID: "w1", FocusedBlockID: "b1", Blocks: []rex.Block{{ID: "b1", Creator: "com.superlogical.terminal"}}}}}, {ID: "two", Label: "Second", ActiveWindowID: "w2", Windows: []rex.Window{{ID: "w2", FocusedBlockID: "b2", Blocks: []rex.Block{{ID: "b2", Creator: "com.superlogical.terminal"}}}}}}, nil)
	return New(context.Background(), f, s, nil, nil), f
}
func update(m Model, msg tea.Msg) (Model, tea.Cmd) { v, c := m.Update(msg); return v.(Model), c }
func TestFilterSelectionAndStalePreview(t *testing.T) {
	m, _ := base()
	m, c := update(m, tea.WindowSizeMsg{Width: 35, Height: 12})
	if c == nil {
		t.Fatal("missing initial preview")
	}
	old := m.generation
	m, _ = update(m, tea.KeyMsg{Type: tea.KeyDown})
	if m.selected[0] != "two" {
		t.Fatalf("selection: %q", m.selected[0])
	}
	next := m.generation
	m, _ = update(m, previewMsg{generation: old, text: "old"})
	if m.preview == "old" {
		t.Fatal("stale preview replaced selected item")
	}
	m, _ = update(m, previewMsg{generation: next, text: "\x1b]2;malicious\x07safe\x1b[2J"})
	if strings.Contains(m.View(), "malicious") || strings.Contains(m.View(), "\x1b]2;") || !strings.Contains(m.View(), "safe") {
		t.Fatalf("unsafe preview: %q", m.View())
	}
	m, _ = update(m, tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("Fir")})
	if m.selected[0] != "one" {
		t.Fatalf("filter selection: %q", m.selected[0])
	}
	m, _ = update(m, tea.WindowSizeMsg{Width: 25, Height: 8})
	if len(strings.Split(m.View(), "\n")) > 8 {
		t.Fatalf("view exceeds height: %q", m.View())
	}
}
func TestLiveAgentStableSelectionAndFocus(t *testing.T) {
	m, f := base()
	m.tab = 2
	m.status.Apply(rex.Event{Kind: "program_status_changed", SessionID: "one", BlockID: "b1", RecordID: "child", Record: &rex.Record{State: "working", Title: "hello\x1b[2J world"}})
	m, _ = update(m, tickMsg{})
	if !strings.Contains(m.View(), "hello world") {
		t.Fatalf("agent absent: %s", m.View())
	}
	m.status.Apply(rex.Event{Kind: "program_status_changed", SessionID: "two", BlockID: "b2", RecordID: "root", Record: &rex.Record{State: "blocked"}})
	m, _ = update(m, tickMsg{})
	if m.selected[2] != "one\x00b1\x00child" {
		t.Fatalf("selection shifted after priority change: %q", m.selected[2])
	}
	m, c := update(m, tea.KeyMsg{Type: tea.KeyEnter})
	if c == nil {
		t.Fatal("missing action")
	}
	if msg, ok := c().(actionMsg); !ok || msg.err != nil {
		t.Fatalf("action: %#v", msg)
	}
	if f.focused != "one/b1" || f.selected != "one/w1" {
		t.Fatalf("focus=%q select=%q", f.focused, f.selected)
	}
}
func TestProjectCreatesWhenNoCWD(t *testing.T) {
	m, f := base()
	m.tab = 1
	m.projects = []projects.Project{{Path: t.TempDir(), Name: "demo"}}
	m, _ = update(m, tickMsg{})
	_, cmd := update(m, tea.KeyMsg{Type: tea.KeyEnter})
	if msg, ok := cmd().(actionMsg); !ok || msg.err != nil {
		t.Fatalf("action: %#v", msg)
	}
	if f.created != 1 || f.selected != "created/new-window" {
		t.Fatalf("created=%d selected=%q", f.created, f.selected)
	}
}
func TestProjectReusesOnlyVerifiedCWD(t *testing.T) {
	m, f := base()
	path := t.TempDir()
	f.details = []rex.SessionDetail{{ID: "one", ActiveWindowID: "w1", Windows: []rex.Window{{ID: "w1", Blocks: []rex.Block{{ID: "b1", Creator: "com.superlogical.terminal", CWD: path}}}}}}
	m.tab = 1
	m.projects = []projects.Project{{Path: path, Name: "demo"}}
	m, _ = update(m, tickMsg{})
	_, cmd := update(m, tea.KeyMsg{Type: tea.KeyEnter})
	if msg, ok := cmd().(actionMsg); !ok || msg.err != nil {
		t.Fatalf("action: %#v", msg)
	}
	if f.created != 0 || f.selected != "one/w1" {
		t.Fatalf("unexpected create/select: %d %q", f.created, f.selected)
	}
}
func TestUntrustedAgentLabelCannotAddRows(t *testing.T) {
	m, _ := base()
	m.tab = 2
	m.status.Apply(rex.Event{Kind: "program_status_changed", SessionID: "one", BlockID: "b1", Record: &rex.Record{State: "blocked", Title: "safe\nFAKE ROW\x1b[2J"}})
	m, _ = update(m, tickMsg{})
	view := m.View()
	if strings.Contains(view, "safe\nFAKE ROW") || strings.Contains(view, "\x1b[2J") || !strings.Contains(view, "safe FAKE ROW") {
		t.Fatalf("unsafe label: %q", view)
	}
}
func TestCancelAndFailure(t *testing.T) {
	m, f := base()
	m, _ = update(m, tickMsg{})
	f.err = errors.New("offline")
	m, cmd := update(m, tea.KeyMsg{Type: tea.KeyEnter})
	m, _ = update(m, cmd())
	if m.err == nil || m.ActionError() == nil || m.busy {
		t.Fatalf("error not displayed: %#v", m)
	}
	_, cmd = update(m, tea.KeyMsg{Type: tea.KeyEsc})
	if cmd == nil {
		t.Fatal("cancel did not quit")
	}
}
func TestSubsequence(t *testing.T) {
	if !subsequence("Catppuccin", "cpc") || subsequence("hello", "xyz") {
		t.Fatal("subsequence mismatch")
	}
}
