package main

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestStateDirAndRuntimePermissions(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("XDG_STATE_HOME", tmp)

	statePath, logPath, err := shareRuntimePaths("demo.example.com")
	if err != nil {
		t.Fatalf("shareRuntimePaths failed: %v", err)
	}

	wantDir := filepath.Join(tmp, "cf")
	info, err := os.Stat(wantDir)
	if err != nil {
		t.Fatalf("stat %s: %v", wantDir, err)
	}
	if got := info.Mode().Perm(); got != 0700 {
		t.Fatalf("stateDir mode = %#o, want 0700", got)
	}

	if err := touchPrivateFile(logPath); err != nil {
		t.Fatalf("touchPrivateFile(logPath): %v", err)
	}
	if err := writeShareState(statePath, &shareState{FullHost: "demo.example.com"}); err != nil {
		t.Fatalf("writeShareState: %v", err)
	}

	for _, p := range []string{statePath, logPath} {
		fi, err := os.Stat(p)
		if err != nil {
			t.Fatalf("stat %s: %v", p, err)
		}
		if got := fi.Mode().Perm(); got != 0600 {
			t.Fatalf("%s mode = %#o, want 0600", p, got)
		}
	}
}

func TestBuildTunnelToken(t *testing.T) {
	creds := tunnelCredentials{
		AccountTag:   "acct-123",
		TunnelID:     "00000000-0000-0000-0000-000000000001",
		TunnelSecret: "c2VjcmV0",
	}
	tok, err := buildTunnelToken(creds)
	if err != nil {
		t.Fatalf("buildTunnelToken: %v", err)
	}
	raw, err := base64.StdEncoding.DecodeString(tok)
	if err != nil {
		t.Fatalf("decode base64: %v", err)
	}
	var got tunnelTokenPayload
	if err := json.Unmarshal(raw, &got); err != nil {
		t.Fatalf("unmarshal token payload: %v", err)
	}
	if got.AccountTag != creds.AccountTag || got.TunnelID != creds.TunnelID || got.TunnelSecret != creds.TunnelSecret {
		t.Fatalf("unexpected token payload: %+v", got)
	}
}

func TestValidateExistingShareApp(t *testing.T) {
	if err := validateExistingShareApp("cf-share: demo.example.com", "demo.example.com", "app-1"); err != nil {
		t.Fatalf("expected cf-share app to be accepted, got error: %v", err)
	}

	for _, name := range []string{
		"cf-access: gitea.example.com",
		"Gitea",
		"",
	} {
		if err := validateExistingShareApp(name, "gitea.example.com", "app-2"); err == nil {
			t.Fatalf("expected unmanaged app %q to be rejected, got nil", name)
		}
	}
}
