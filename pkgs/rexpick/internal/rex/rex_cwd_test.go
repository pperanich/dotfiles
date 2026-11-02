package rex

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInspectProcessCWD(t *testing.T) {
	dir := t.TempDir()
	link := filepath.Join(t.TempDir(), "linked")
	if e := os.Symlink(dir, link); e != nil {
		t.Fatal(e)
	}
	c := fake(t, fmt.Sprintf(`case "$*" in
 *'session inspect'*) printf '%%s' '{"session_id":"s","windows":[{"window_id":"w","layers":[{"blocks":[{"block_id":"b","creator_name":"com.superlogical.terminal"}]}]}]}' ;;
 *' process') printf '%%s' '{"foreground":{"cwd":%q,"name":"Python"}}' ;;
 *' pwd') exit 9 ;;
 esac`, link))
	d, e := c.Inspect(context.Background(), "s")
	canonical, _ := filepath.EvalSymlinks(dir)
	if e != nil || d.Windows[0].Blocks[0].CWD != canonical {
		t.Fatalf("cwd %+v %v", d, e)
	}
}
func TestPWDFallbackAndNonlocalRejection(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "repo name")
	if e := os.Mkdir(dir, 0700); e != nil {
		t.Fatal(e)
	}
	canonical, _ := filepath.EvalSymlinks(dir)
	for _, tc := range []struct{ pwd, want string }{{"file://" + strings.ReplaceAll(dir, " ", "%20"), canonical}, {"file://remote" + dir, ""}, {"relative/path", ""}, {"file:///definitely/missing/rexpick", ""}} {
		t.Run(tc.pwd, func(t *testing.T) {
			c := fake(t, "case \"$*\" in *' process') printf '%s' '{\"foreground\":null}' ;; *' pwd') printf '%s' '{\"pwd\":\""+tc.pwd+"\"}' ;; esac")
			got, _ := c.BlockCWD(context.Background(), "s", "b")
			if got != tc.want {
				t.Fatalf("got %q want %q", got, tc.want)
			}
		})
	}
}
func TestFixtureRootAndChildRemoval(t *testing.T) { // Mirrors /tmp/rex-go-prototype.bqGKQi/live/osc-events.json without requiring that external file.
	for _, tc := range []struct {
		raw, id string
		removed bool
	}{{`{"type":"session_event","payload":{"session_id":"s","event":{"type":"block_event","payload":{"block_id":"b","name":"program_status_changed","payload":{"id":"","record":{"state":"idle","msg":"Synthetic fixture ready"}}}}}}`, "", false}, {`{"type":"session_event","payload":{"session_id":"s","event":{"type":"block_event","payload":{"block_id":"b","name":"program_status_changed","payload":{"id":"worker/test","record":{"id":"worker/test","state":"blocked"}}}}}}`, "worker/test", false}, {`{"type":"session_event","payload":{"session_id":"s","event":{"type":"block_event","payload":{"block_id":"b","name":"program_status_removed","payload":{"ids":["worker/test"]}}}}}`, "worker/test", true}, {`{"type":"session_event","payload":{"session_id":"s","event":{"type":"block_event","payload":{"block_id":"b","name":"program_status_removed","payload":{"ids":[""]}}}}}`, "", true}} {
		ev, e := ParseEvent([]byte(tc.raw))
		if e != nil {
			t.Fatal(e)
		}
		if tc.removed {
			if len(ev.RemovedIDs) != 1 || ev.RemovedIDs[0] != tc.id {
				t.Fatal(ev)
			}
		} else if ev.Record == nil || ev.RecordID != tc.id {
			t.Fatal(ev)
		}
	}
}
