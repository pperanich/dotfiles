package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/pperanich/rexpick/internal/projects"
	"github.com/pperanich/rexpick/internal/rex"
	"github.com/pperanich/rexpick/internal/state"
	"github.com/pperanich/rexpick/internal/ui"
)

// This fake Rex is a subprocess, not the user's server. Assertions cover the
// transport, discovery, status parser/model, and UI action command together.
func TestFakeRexEndToEndNavigation(t *testing.T) {
	for _, scenario := range []struct{ name, tab, cwd, want string }{
		{"session", "session", "matched", "session.select"},
		{"project-reuse", "project", "matched", "session.select"},
		{"project-create", "project", "missing", "new demo --cwd"},
		{"agent", "agent", "matched", "session.focus_block"},
	} {
		t.Run(scenario.name, func(t *testing.T) {
			dir := t.TempDir()
			canonicalDir, err := filepath.EvalSymlinks(dir)
			if err != nil {
				t.Fatal(err)
			}
			project := filepath.Join(canonicalDir, "demo")
			if err := os.MkdirAll(filepath.Join(project, ".git"), 0700); err != nil {
				t.Fatal(err)
			}
			paths, err := projects.Discover(context.Background(), []projects.Root{{Path: dir, Depth: 1}})
			if err != nil || len(paths) != 1 || paths[0].Path != project {
				t.Fatalf("discovery: %v %v", paths, err)
			}
			log := filepath.Join(dir, "calls")
			cwd := project
			if scenario.cwd == "missing" {
				cwd = filepath.Join(dir, "deleted")
			}
			encodedCWD, _ := json.Marshal(cwd)
			script := "#!/bin/sh\necho \"$*\" >> '" + strings.ReplaceAll(log, "'", "'\\''") + "'\ncase \"$*\" in\n" +
				" *'client ls --json') echo '{\"clients\":[{\"client_id\":\"client:app\",\"info\":{\"kind\":\"app\"},\"connection_state\":\"connected\"}]}' ;;\n" +
				" *'ls --json') echo '{\"sessions\":[{\"session_id\":\"session:one\",\"label\":\"demo\"}]}' ;;\n" +
				" *'session inspect session:one --json') echo '{\"session_id\":\"session:one\",\"label\":\"demo\",\"active_window_id\":\"window:one\",\"windows\":[{\"window_id\":\"window:one\",\"focused_block_id\":\"block:one\",\"layers\":[{\"blocks\":[{\"block_id\":\"block:one\",\"creator_name\":\"com.superlogical.terminal\"}]}]}]}' ;;\n" +
				" *'block:one process') echo '{\"foreground\":{\"cwd\":" + string(encodedCWD) + "}}' ;;\n" +
				" *'block:one pwd') echo '{\"pwd\":\"\"}' ;;\n" +
				" *'block:one program_status') echo '{\"records\":[{\"id\":\"\",\"state\":\"idle\",\"title\":\"root\"}]}' ;;\n" +
				" *'new demo --cwd '* ) echo '{\"session_id\":\"session:new\",\"initial_windows\":[{\"window_id\":\"window:new\",\"block_ids\":[\"block:new\"]}]}' ;;\n" +
				" *'session.focus_block '* | *'session.select '*) echo '{}' ;;\n" +
				" *) echo \"unexpected: $*\" >&2; exit 1 ;;\nesac\n"
			executable := filepath.Join(dir, "rex")
			if err := os.WriteFile(executable, []byte(script), 0700); err != nil {
				t.Fatal(err)
			}
			client, err := rex.New(rex.Config{Executable: executable, ClientID: "client:app"})
			if err != nil {
				t.Fatal(err)
			}
			if id, err := client.ResolveClient(context.Background(), "client:app"); err != nil || id != "client:app" {
				t.Fatalf("app: %s %v", id, err)
			}
			sessions, err := client.Sessions(context.Background())
			if err != nil || len(sessions) != 1 {
				t.Fatalf("sessions %v %v", sessions, err)
			}
			detail, err := client.Inspect(context.Background(), sessions[0].ID)
			if err != nil {
				t.Fatal(err)
			}
			records, err := client.Status(context.Background(), detail.ID, "block:one")
			if err != nil {
				t.Fatal(err)
			}
			model := state.New()
			model.ApplySnapshot([]rex.SessionDetail{detail}, map[state.BlockKey][]rex.Record{{SessionID: detail.ID, BlockID: "block:one"}: records})
			event := []byte(`{"type":"session_event","payload":{"session_id":"session:one","event":{"type":"block_event","payload":{"block_id":"block:one","name":"program_status_changed","payload":{"id":"child","record":{"state":"blocked","title":"Needs review"}}}}}}`)
			parsed, err := rex.ParseEvent(event)
			if err != nil {
				t.Fatal(err)
			}
			model.Apply(parsed)
			if got := model.Agents(); len(got) != 2 || got[0].RecordID != "child" || got[0].WindowID != "window:one" {
				t.Fatalf("agents %+v", got)
			}
			picker := ui.New(context.Background(), client, model, paths, nil)
			switch scenario.tab {
			case "project":
				var next tea.Model
				next, _ = picker.Update(tea.KeyMsg{Type: tea.KeyTab})
				picker = next.(ui.Model)
			case "agent":
				for i := 0; i < 2; i++ {
					next, _ := picker.Update(tea.KeyMsg{Type: tea.KeyTab})
					picker = next.(ui.Model)
				}
			}
			if !strings.Contains(picker.View(), "rexpick") {
				t.Fatalf("missing picker UI: %q", picker.View())
			}
			_, cmd := picker.Update(tea.KeyMsg{Type: tea.KeyEnter})
			if cmd == nil {
				t.Fatal("missing navigation command")
			}
			next, _ := picker.Update(cmd()) // Action is synchronous; surface failures through UI model.
			if err := next.(ui.Model).ActionError(); err != nil {
				t.Fatalf("picker action: %v", err)
			}
			data, err := os.ReadFile(log)
			if err != nil {
				t.Fatal(err)
			}
			output := string(data)
			if !strings.Contains(output, scenario.want) {
				t.Fatalf("missing action %q: %s", scenario.want, output)
			}
			if scenario.name == "project-reuse" && strings.Contains(output, "new demo --cwd") {
				t.Fatalf("unnecessary session creation: %s", output)
			}
			if scenario.name == "agent" && (!strings.Contains(output, "session.focus_block") || !strings.Contains(output, "session.select")) {
				t.Fatalf("agent navigation incomplete: %s", output)
			}
		})
	}
}
