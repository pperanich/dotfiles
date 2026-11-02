// Package ui provides the terminal picker. All Rex operations are injected for testing.
package ui

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/pperanich/rexpick/internal/projects"
	"github.com/pperanich/rexpick/internal/rex"
	"github.com/pperanich/rexpick/internal/state"
)

type Backend interface {
	state.Source
	Capture(context.Context, string, string) (string, error)
	NewSession(context.Context, string, string) (rex.SessionDetail, error)
	Select(context.Context, string, string) error
	FocusBlock(context.Context, string, string) error
}

type item struct {
	id, label, session, window, block string
	project                           projects.Project
}
type previewMsg struct {
	generation uint64
	text       string
	err        error
}
type actionMsg struct{ err error }
type tickMsg struct{}

// Model keeps UI-only selection and preview state; the concurrent status model
// owns the Rex snapshot and subscription. Cancel the context on program exit.
type Model struct {
	backend       Backend
	status        *state.Model
	projects      []projects.Project
	notices       <-chan error
	ctx           context.Context
	tab           int
	query         string
	selected      [3]string
	index         int
	width, height int
	preview       string
	generation    uint64
	previewID     string
	busy          bool
	err           error
	actionFailure error
	help          bool
}

func New(ctx context.Context, backend Backend, status *state.Model, projectsList []projects.Project, notices <-chan error) Model {
	return Model{ctx: ctx, backend: backend, status: status, projects: projectsList, notices: notices, width: 90, height: 25}
}

// ActionError reports a failed navigation after the picker closes.
func (m Model) ActionError() error { return m.actionFailure }

func (m Model) Init() tea.Cmd { return tick }
func tick() tea.Msg {
	return tea.Tick(350*time.Millisecond, func(time.Time) tea.Msg { return tickMsg{} })()
}
func (m Model) entries() []item {
	var result []item
	switch m.tab {
	case 0:
		for _, s := range m.status.Sessions() {
			result = append(result, item{id: s.ID, session: s.ID, label: s.Label})
		}
	case 1:
		for _, p := range m.projects {
			result = append(result, item{id: p.Path, project: p, label: p.Name + "  " + p.Path})
		}
	case 2:
		for _, a := range m.status.Agents() {
			result = append(result, item{id: a.SessionID + "\x00" + a.BlockID + "\x00" + a.RecordID, session: a.SessionID, window: a.WindowID, block: a.BlockID, label: strings.Join([]string{"[" + a.State + "]", a.Title, a.Message, a.SessionID}, "  ")})
		}
	}
	filtered := result[:0]
	for _, v := range result {
		v.label = oneLine(v.label)
		if subsequence(v.label, m.query) {
			filtered = append(filtered, v)
		}
	}
	return filtered
}
func subsequence(haystack, needle string) bool {
	n := []rune(strings.ToLower(needle))
	if len(n) == 0 {
		return true
	}
	i := 0
	for _, r := range strings.ToLower(haystack) {
		if r == n[i] {
			i++
			if i == len(n) {
				return true
			}
		}
	}
	return false
}
func (m *Model) current(entries []item) (item, bool) {
	if len(entries) == 0 {
		m.index = 0
		return item{}, false
	}
	for i, e := range entries {
		if e.id == m.selected[m.tab] {
			m.index = i
			return e, true
		}
	}
	if m.index >= len(entries) {
		m.index = len(entries) - 1
	}
	if m.index < 0 {
		m.index = 0
	}
	e := entries[m.index]
	m.selected[m.tab] = e.id
	return e, true
}
func (m *Model) previewCommand(e item) tea.Cmd {
	m.generation++
	gen := m.generation
	m.previewID = e.id
	m.preview = "Loading preview..."
	if m.tab == 1 {
		m.preview = rex.Sanitize(e.project.Path)
		return nil
	}
	ctx, b := m.ctx, m.backend
	return func() tea.Msg {
		session, block := e.session, e.block
		if block == "" {
			d, err := b.Inspect(ctx, session)
			if err != nil {
				return previewMsg{generation: gen, err: err}
			}
			for _, w := range d.Windows {
				if w.ID == d.ActiveWindowID {
					block = w.FocusedBlockID
					if block == "" && len(w.Blocks) > 0 {
						block = w.Blocks[0].ID
					}
					break
				}
			}
			if block == "" {
				return previewMsg{generation: gen, text: "No focused terminal block."}
			}
		}
		text, err := b.Capture(ctx, session, block)
		return previewMsg{generation: gen, text: rex.Sanitize(text), err: err}
	}
}
func (m *Model) synchronize() tea.Cmd {
	entries := m.entries()
	e, ok := m.current(entries)
	if !ok {
		if m.previewID != "" {
			m.generation++
			m.previewID = ""
			m.preview = ""
		}
		return nil
	}
	if e.id != m.previewID {
		return m.previewCommand(e)
	}
	return nil
}
func (m Model) Update(message tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := message.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tickMsg:
		for m.notices != nil {
			select {
			case err, ok := <-m.notices:
				if !ok {
					m.notices = nil
				} else if err != nil {
					m.err = err
				}
			default:
				goto drained
			}
		}
	drained:
		return m, multi(m.synchronize(), tick)
	case previewMsg:
		if msg.generation == m.generation {
			if msg.err != nil {
				m.preview = "Preview unavailable: " + rex.Sanitize(msg.err.Error())
			} else {
				m.preview = rex.Sanitize(msg.text)
			}
		}
	case actionMsg:
		m.busy = false
		if msg.err == nil {
			return m, tea.Quit
		}
		m.err = msg.err
		m.actionFailure = msg.err
	case tea.KeyMsg:
		if msg.Type == tea.KeyCtrlC || msg.Type == tea.KeyEsc {
			return m, tea.Quit
		}
		if m.busy {
			return m, nil
		}
		switch msg.Type {
		case tea.KeyTab, tea.KeyShiftTab:
			delta := 1
			if msg.Type == tea.KeyShiftTab {
				delta = -1
			}
			m.tab = (m.tab + delta + 3) % 3
			m.query = ""
			m.index = 0
			m.previewID = ""
			m.generation++
		case tea.KeyUp, tea.KeyCtrlP:
			if m.index > 0 {
				m.index--
			}
			m.selected[m.tab] = ""
		case tea.KeyDown, tea.KeyCtrlN:
			if m.index < len(m.entries())-1 {
				m.index++
			}
			m.selected[m.tab] = ""
		case tea.KeyBackspace, tea.KeyDelete:
			r := []rune(m.query)
			if len(r) > 0 {
				m.query = string(r[:len(r)-1])
				m.index = 0
				m.selected[m.tab] = ""
			}
		case tea.KeyEnter:
			entries := m.entries()
			e, ok := m.current(entries)
			if !ok {
				return m, nil
			}
			m.busy = true
			m.err = nil
			m.actionFailure = nil
			return m, m.actionCommand(e)
		case tea.KeyRunes:
			if string(msg.Runes) == "?" && m.query == "" {
				m.help = !m.help
			} else {
				m.query += string(msg.Runes)
				m.index = 0
				m.selected[m.tab] = ""
			}
		}
	}
	return m, m.synchronize()
}
func multi(a, b tea.Cmd) tea.Cmd {
	if a == nil {
		return b
	}
	return tea.Batch(a, b)
}
func (m Model) actionCommand(e item) tea.Cmd {
	ctx, b, tab := m.ctx, m.backend, m.tab
	return func() tea.Msg {
		var err error
		switch tab {
		case 0:
			err = b.Select(ctx, e.session, "")
		case 2:
			if e.window == "" || e.block == "" {
				err = errors.New("agent block/window unavailable; wait for a fresh snapshot")
			} else {
				err = b.FocusBlock(ctx, e.session, e.block)
				if err == nil {
					err = b.Select(ctx, e.session, e.window)
				}
			}
		case 1:
			var sessions []rex.Session
			sessions, err = b.Sessions(ctx)
			details := make([]rex.SessionDetail, 0, len(sessions))
			if err == nil {
				for _, s := range sessions {
					var d rex.SessionDetail
					d, err = b.Inspect(ctx, s.ID)
					if err != nil {
						break
					}
					details = append(details, d)
				}
			}
			if err == nil {
				id, window, ok := projects.MatchSession(e.project, details)
				if !ok {
					var created rex.SessionDetail
					label := oneLine(e.project.Name)
					if label == "" || strings.HasPrefix(label, "-") {
						label = "Project " + label
					}
					created, err = b.NewSession(ctx, label, e.project.Path)
					id, window = created.ID, created.ActiveWindowID
				}
				if err == nil {
					err = b.Select(ctx, id, window)
				}
			}
		}
		return actionMsg{err: err}
	}
}

var heading = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#cba6f7"))
var active = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#a6e3a1"))
var warning = lipgloss.NewStyle().Foreground(lipgloss.Color("#f38ba8"))

func (m Model) View() string {
	width, height := m.width, m.height
	if width < 20 {
		width = 20
	}
	if height < 6 {
		height = 6
	}
	tabs := []string{"Sessions", "Projects", "Agents"}
	for i := range tabs {
		if i == m.tab {
			tabs[i] = active.Render("[" + tabs[i] + "]")
		}
	}
	header := heading.Render("rexpick") + "  " + strings.Join(tabs, "  ")
	if width < 48 {
		header = heading.Render("rexpick") + "  " + active.Render("["+[]string{"Sessions", "Projects", "Agents"}[m.tab]+"]")
	}
	lines := []string{header, short("Search: "+oneLine(m.query)+"_", width)}
	if m.help {
		lines = append(lines, short("Tab views  ↑/↓ select  Enter open  Esc/Ctrl-C close  ? help", width))
	}
	if m.busy {
		lines = append(lines, "Opening...")
	} else if m.err != nil {
		prefix := "Last Rex notice: "
		if m.actionFailure != nil {
			prefix = "Error: "
		}
		lines = append(lines, warning.Render(short(prefix+oneLine(m.err.Error()), width)))
	}
	entries := m.entries()
	selected := m.selected[m.tab]
	if selected == "" && len(entries) > 0 {
		selected = entries[0].id
	}
	listRows := (height - len(lines) - 3) / 2
	if listRows < 1 {
		listRows = 1
	}
	if len(entries) == 0 {
		lines = append(lines, "(no matches)")
	} else {
		pos := 0
		for i, e := range entries {
			if e.id == selected {
				pos = i
				break
			}
		}
		start := pos - listRows/2
		if start < 0 {
			start = 0
		}
		if start+listRows > len(entries) {
			start = len(entries) - listRows
		}
		if start < 0 {
			start = 0
		}
		for _, e := range entries[start:min(start+listRows, len(entries))] {
			marker := "  "
			if e.id == selected {
				marker = "> "
			}
			line := marker + e.label
			if e.id == selected {
				line = active.Render(short(line, width))
			} else {
				line = short(line, width)
			}
			lines = append(lines, line)
		}
	}
	lines = append(lines, heading.Render("Preview:"))
	remaining := height - len(lines) - 1
	if remaining < 0 {
		remaining = 0
	}
	for _, line := range strings.Split(rex.Sanitize(m.preview), "\n") {
		if remaining == 0 {
			break
		}
		lines = append(lines, short(line, width))
		remaining--
	}
	lines = append(lines, short(fmt.Sprintf("%d sessions / %d projects / %d agents", len(m.status.Sessions()), len(m.projects), len(m.status.Agents())), width))
	for len(lines) > height {
		lines = append(lines[:height-1], lines[len(lines)-1])
	}
	return strings.Join(lines, "\n")
}
func oneLine(s string) string {
	s = rex.Sanitize(s)
	s = strings.NewReplacer("\n", " ", "\r", " ", "\t", " ").Replace(s)
	return short(s, 512)
}

func short(s string, width int) string {
	r := []rune(s)
	if len(r) > width {
		if width > 1 {
			return string(r[:width-1]) + "…"
		}
		return string(r[:width])
	}
	return s
}
