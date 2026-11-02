package main

import (
	"path/filepath"
	"testing"
)

func TestParseRoots(t *testing.T) {
	home := t.TempDir()
	defaults, err := parseRoots("", home)
	if err != nil || len(defaults) != 4 || defaults[0].Path != filepath.Join(home, "dotfiles") {
		t.Fatalf("defaults: %v %v", defaults, err)
	}
	custom, err := parseRoots("/tmp/a:0,/tmp/b:3", home)
	if err != nil || len(custom) != 2 || custom[0].Depth != 0 || custom[1].Depth != 3 {
		t.Fatalf("custom: %v %v", custom, err)
	}
	for _, s := range []string{"/tmp:33", "/tmp:-1", "/tmp:no", ",/tmp", ":1", "/tmp:1x"} {
		if _, err := parseRoots(s, home); err == nil {
			t.Errorf("accepted bad root %q", s)
		}
	}
}
func TestHelpDoesNotNeedRex(t *testing.T) {
	if err := run([]string{"--help"}); err != nil {
		t.Fatal(err)
	}
}
func TestRejectMissingRex(t *testing.T) {
	if err := run([]string{"--rex=/definitely/missing/rex"}); err == nil {
		t.Fatal("missing executable accepted")
	}
}
