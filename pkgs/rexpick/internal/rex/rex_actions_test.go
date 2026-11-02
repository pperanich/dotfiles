package rex

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestActionsUseLiteralArgv(t *testing.T) {
	dir := t.TempDir()
	log := filepath.Join(dir, "args")
	script := "printf '%s\\n' \"$@\" > '" + log + "'\ncase \"$*\" in *'new '*) echo '{\"session_id\":\"s\"}' ;; *'client ls --json') echo '{\"clients\":[{\"client_id\":\"client:test\",\"info\":{\"kind\":\"app\",\"label\":\"test\"},\"connection_state\":\"connected\"}]}' ;; esac\n"
	c := fake(t, script)
	ctx := context.Background()
	label := "$(touch /tmp/never-run-rexpick-test)"
	_, e := c.NewSession(ctx, label, "/tmp/name with spaces")
	if e != nil {
		t.Fatal(e)
	}
	data, e := os.ReadFile(log)
	if e != nil {
		t.Fatal(e)
	}
	if !strings.Contains(string(data), label+"\n") || !strings.Contains(string(data), "/tmp/name with spaces\n") || !strings.Contains(string(data), "--autostart=false\n") {
		t.Fatalf("wrong argv %q", data)
	}
	if e = c.FocusBlock(ctx, "s", "b\"\\danger"); e != nil {
		t.Fatal(e)
	}
	data, _ = os.ReadFile(log)
	if !strings.Contains(string(data), `{"block_id":"b\"\\danger"}`) {
		t.Fatalf("focus escaping %q", data)
	}
	if e = c.Select(ctx, "s", "w"); e != nil {
		t.Fatal(e)
	}
	data, _ = os.ReadFile(log)
	if !strings.Contains(string(data), "client:test\n") || !strings.Contains(string(data), `{"session_id":"s","window_id":"w"}`) {
		t.Fatalf("select args %q", data)
	}
}
func TestRejectFlagLikeLabel(t *testing.T) {
	c := fake(t, "exit 1")
	if _, e := c.NewSession(context.Background(), "--shell=evil", "/tmp"); e == nil {
		t.Fatal("flag-like label accepted")
	}
	if _, e := c.Inspect(context.Background(), "--json"); e == nil {
		t.Fatal("flag-like session ID accepted")
	}
}
func TestSelectNeedsClient(t *testing.T) {
	c := fake(t, "exit 1")
	c.config.ClientID = ""
	if e := c.Select(context.Background(), "s", ""); e == nil {
		t.Fatal("selection without app client")
	}
}
func TestResolveClient(t *testing.T) {
	c := fake(t, `printf '{"clients":[{"client_id":"cli","info":{"kind":"cli","label":"same"},"connection_state":"connected"},{"client_id":"a","info":{"kind":"app","label":"same"},"connection_state":"connected"},{"client_id":"b","info":{"kind":"app","label":"same"},"connection_state":"connected"}]}'`)
	ctx := context.Background()
	if _, e := c.ResolveClient(ctx, ""); e == nil {
		t.Fatal("ambiguous empty client")
	}
	if _, e := c.ResolveClient(ctx, "same"); e == nil {
		t.Fatal("ambiguous label")
	}
	if id, e := c.ResolveClient(ctx, "a"); e != nil || id != "a" {
		t.Fatalf("resolve %s %v", id, e)
	}
	if _, e := c.ResolveClient(ctx, "cli"); e == nil {
		t.Fatal("CLI client accepted")
	}
}
func TestParseRemoval(t *testing.T) {
	ev, e := ParseEvent([]byte(`{"type":"session_event","payload":{"session_id":"s","event":{"type":"block_event","payload":{"block_id":"b","name":"program_status_removed","payload":{"ids":["","child"]}}}}}`))
	if e != nil || ev.Kind != "program_status_removed" || len(ev.RemovedIDs) != 2 || ev.RemovedIDs[0] != "" {
		t.Fatalf("%+v %v", ev, e)
	}
}
