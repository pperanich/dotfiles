package projects

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/pperanich/rexpick/internal/rex"
)

func canonicalTemp(t *testing.T) string {
	t.Helper()
	path, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	return path
}

func repository(t *testing.T, path string, worktree bool) string {
	t.Helper()
	if err := os.MkdirAll(path, 0o755); err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(path, ".git")
	if worktree {
		if err := os.WriteFile(marker, []byte("gitdir: /unrelated/read-only/path\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	} else if err := os.Mkdir(marker, 0o755); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestDefaultRoots(t *testing.T) {
	home := t.TempDir()
	want := []Root{
		{filepath.Join(home, "dotfiles"), 1},
		{filepath.Join(home, "nix-private"), 1},
		{filepath.Join(home, "Documents", "repos"), 2},
		{filepath.Join(home, "repos"), 2},
	}
	if got := DefaultRoots(home); !reflect.DeepEqual(got, want) {
		t.Fatalf("roots: got %#v, want %#v", got, want)
	}
}

func TestDiscoverDepthWorktreesAndOverlap(t *testing.T) {
	base := canonicalTemp(t)
	root := filepath.Join(base, "repos")
	repository(t, root, false)
	a := repository(t, filepath.Join(root, "a"), true)
	b := repository(t, filepath.Join(root, "sub", "b"), false)
	deep := repository(t, filepath.Join(root, "sub", "b", "nested"), false)
	if err := os.MkdirAll(filepath.Join(a, "src"), 0o755); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		depth int
		want  []Project
	}{
		{0, []Project{{root, "repos"}, {a, "a"}}},
		{1, []Project{{root, "repos"}, {a, "a"}}},
		{2, []Project{{root, "repos"}, {a, "a"}, {b, "b"}}},
	} {
		got, err := Discover(context.Background(), []Root{{root, tc.depth}, {a, 0}, {root, 0}})
		if err != nil {
			t.Fatal(err)
		}
		// Nested explicit root is always discovered, even with parent depth 0.
		if !reflect.DeepEqual(got, tc.want) {
			t.Errorf("depth %d: got %#v, want %#v", tc.depth, got, tc.want)
		}
	}
	got, err := Discover(context.Background(), []Root{{root, 0}, {root, 3}})
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 4 || got[3].Path != deep {
		t.Fatalf("overlap with deeper root: %#v", got)
	}
}

func TestDiscoverMissingRootsSymlinksAndHome(t *testing.T) {
	base := canonicalTemp(t)
	t.Setenv("HOME", base)
	root := filepath.Join(base, "repos")
	real := repository(t, filepath.Join(root, "real"), true)
	if err := os.Symlink(root, filepath.Join(root, "real", "loop")); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	if err := os.Symlink(real, filepath.Join(root, "alias")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(base, "missing"), filepath.Join(base, "dangling")); err != nil {
		t.Fatal(err)
	}
	got, err := Discover(context.Background(), []Root{{"~/repos", 8}, {filepath.Join(root, "alias"), 2}, {filepath.Join(base, "missing"), 0}, {filepath.Join(base, "dangling"), 0}})
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, []Project{{real, "real"}}) {
		t.Fatalf("symlink cycle/dedupe or missing roots: %#v", got)
	}
	// A symlinked marker is not itself a Git directory or worktree file.
	other := filepath.Join(base, "not-repo")
	if err := os.Mkdir(other, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(real, ".git"), filepath.Join(other, ".git")); err != nil {
		t.Fatal(err)
	}
	got, err = Discover(context.Background(), []Root{{other, 0}})
	if err != nil || len(got) != 0 {
		t.Fatalf("symlinked marker accepted: %#v, %v", got, err)
	}
}

func TestDiscoverCancellationAndInputErrors(t *testing.T) {
	root := t.TempDir()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := Discover(ctx, []Root{{root, 0}}); !errors.Is(err, context.Canceled) {
		t.Fatalf("cancel: %v", err)
	}
	for _, roots := range [][]Root{{{root, -1}}, {{root, maxDepth + 1}}, {{"", 0}}} {
		if _, err := Discover(context.Background(), roots); err == nil {
			t.Errorf("accepted invalid roots %#v", roots)
		}
	}
	file := filepath.Join(root, "file")
	if err := os.WriteFile(file, []byte("not directory"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Discover(context.Background(), []Root{{file, 1}}); err == nil || !strings.Contains(err.Error(), "not a directory") {
		t.Fatalf("root file: %v", err)
	}
}

func terminal(cwd, id string) rex.Block {
	return rex.Block{ID: id, Creator: "com.superlogical.terminal", CWD: cwd}
}

func TestMatchSessionUniqueVerifiedCWD(t *testing.T) {
	base := canonicalTemp(t)
	a := repository(t, filepath.Join(base, "a", "shared"), true)
	b := repository(t, filepath.Join(base, "b", "shared"), false)
	alias := filepath.Join(base, "alias")
	if err := os.Symlink(a, alias); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	project := Project{Path: alias, Name: "shared"}
	matching := rex.SessionDetail{ID: "correct", Label: "not the project label", ActiveWindowID: "other", Windows: []rex.Window{
		{ID: "other", Blocks: []rex.Block{terminal(b, "b")}},
		{ID: "target", Blocks: []rex.Block{terminal(a, "a")}},
	}}
	wrong := rex.SessionDetail{ID: "same basename", Label: "shared", Windows: []rex.Window{{ID: "wrong", Blocks: []rex.Block{terminal(b, "b")}}}}
	for _, tc := range []struct {
		name     string
		sessions []rex.SessionDetail
		id, win  string
		ok       bool
	}{
		{"unique cwd, even different label", []rex.SessionDetail{wrong, matching}, "correct", "target", true},
		{"no cwd, label alone insufficient", []rex.SessionDetail{{ID: "shared", Label: "shared", Windows: []rex.Window{{ID: "w", Blocks: []rex.Block{terminal("", "b")}}}}}, "", "", false},
		{"two sessions same cwd", []rex.SessionDetail{matching, {ID: "second", Windows: []rex.Window{{ID: "x", Blocks: []rex.Block{terminal(a, "a")}}}}}, "", "", false},
		{"same session active matching window", []rex.SessionDetail{{ID: "both", ActiveWindowID: "w2", Windows: []rex.Window{{ID: "w1", Blocks: []rex.Block{terminal(a, "a")}}, {ID: "w2", Blocks: []rex.Block{terminal(a, "b")}}}}}, "both", "w2", true},
		{"same session ambiguous windows", []rex.SessionDetail{{ID: "both", ActiveWindowID: "unrelated", Windows: []rex.Window{{ID: "w1", Blocks: []rex.Block{terminal(a, "a")}}, {ID: "w2", Blocks: []rex.Block{terminal(a, "b")}}}}}, "", "", false},
		{"reject nonterminal cwd", []rex.SessionDetail{{ID: "guess", Windows: []rex.Window{{ID: "w", Blocks: []rex.Block{{Creator: "other", CWD: a}}}}}}, "", "", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			id, win, ok := MatchSession(project, tc.sessions)
			if id != tc.id || win != tc.win || ok != tc.ok {
				t.Fatalf("got (%q,%q,%t), want (%q,%q,%t)", id, win, ok, tc.id, tc.win, tc.ok)
			}
		})
	}
	if _, _, ok := MatchSession(Project{Path: filepath.Join(base, "missing")}, []rex.SessionDetail{matching}); ok {
		t.Fatal("nonexistent project matched")
	}
	if _, _, ok := MatchSession(Project{Path: "relative"}, []rex.SessionDetail{matching}); ok {
		t.Fatal("relative project matched")
	}
}
