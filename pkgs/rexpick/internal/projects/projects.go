// Package projects discovers local Git repository and worktree directories
// without invoking Git or modifying the filesystem.
package projects

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/pperanich/rexpick/internal/rex"
)

type Root struct {
	Path  string
	Depth int // 0 checks the root; 1 also checks its immediate children.
}

type Project struct {
	Path string // Canonical absolute directory.
	Name string // Directory basename, for display only; never a session identity.
}

func DefaultRoots(home string) []Root {
	return []Root{
		{Path: filepath.Join(home, "dotfiles"), Depth: 1},
		{Path: filepath.Join(home, "nix-private"), Depth: 1},
		{Path: filepath.Join(home, "Documents", "repos"), Depth: 2},
		{Path: filepath.Join(home, "repos"), Depth: 2},
	}
}

// Limits protect a picker from an accidentally broad root or excessive depth.
// A limit produces an error rather than silently omitting projects.
const (
	maxDepth       = 32
	maxDirectories = 10000
	maxEntries     = 50000
)

// Discover visits directories in sorted name order, including nested repositories,
// up to the depth of each configured root. Explicit symlink roots are resolved once;
// discovered symlink directories are never followed. Missing roots are optional.
func Discover(ctx context.Context, roots []Root) ([]Project, error) {
	if ctx == nil {
		return nil, errors.New("nil discovery context")
	}
	projects := make(map[string]Project)
	visited := make(map[string]int) // Highest remaining depth already visited.
	count, entriesSeen := 0, 0
	var visit func(string, int) error
	visit = func(path string, remaining int) error {
		if err := ctx.Err(); err != nil {
			return err
		}
		if previous, ok := visited[path]; ok && previous >= remaining {
			return nil
		}
		count++
		if count > maxDirectories {
			return fmt.Errorf("project discovery exceeds %d directories", maxDirectories)
		}
		visited[path] = remaining
		marker, err := os.Lstat(filepath.Join(path, ".git"))
		if err == nil && (marker.IsDir() || marker.Mode().IsRegular()) {
			projects[path] = Project{Path: path, Name: filepath.Base(path)}
		} else if err != nil && !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("inspect %s: %w", filepath.Join(path, ".git"), err)
		}
		if remaining == 0 {
			return nil
		}
		// Read at most the remaining entry budget plus one, rather than
		// allocating an unbounded directory listing before enforcing limits.
		dir, err := os.Open(path)
		if errors.Is(err, os.ErrNotExist) { // Directory removed mid-scan.
			return nil
		}
		if err != nil {
			return fmt.Errorf("open project directory %s: %w", path, err)
		}
		entries, readErr := dir.ReadDir(maxEntries - entriesSeen + 1)
		closeErr := dir.Close()
		if readErr != nil && !errors.Is(readErr, io.EOF) {
			return fmt.Errorf("read project directory %s: %w", path, readErr)
		}
		if closeErr != nil {
			return fmt.Errorf("close project directory %s: %w", path, closeErr)
		}
		entriesSeen += len(entries)
		if entriesSeen > maxEntries {
			return fmt.Errorf("project discovery exceeds %d directory entries", maxEntries)
		}
		sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
		for _, entry := range entries {
			if err := ctx.Err(); err != nil {
				return err
			}
			if entry.Name() == ".git" || !entry.IsDir() || entry.Type()&os.ModeSymlink != 0 {
				continue
			}
			child := filepath.Join(path, entry.Name())
			if err := visit(child, remaining-1); err != nil {
				return err
			}
		}
		return nil
	}
	for _, root := range roots {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		if root.Depth < 0 || root.Depth > maxDepth {
			return nil, fmt.Errorf("invalid discovery depth %d for %q (expected 0..%d)", root.Depth, root.Path, maxDepth)
		}
		path, err := expandRoot(root.Path)
		if err != nil {
			return nil, err
		}
		path, err = filepath.EvalSymlinks(path)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, fmt.Errorf("resolve project root %s: %w", root.Path, err)
		}
		info, err := os.Stat(path)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, fmt.Errorf("stat project root %s: %w", path, err)
		}
		if !info.IsDir() {
			return nil, fmt.Errorf("project root %s is not a directory", path)
		}
		if err := visit(path, root.Depth); err != nil {
			return nil, err
		}
	}
	result := make([]Project, 0, len(projects))
	for _, project := range projects {
		result = append(result, project)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].Path < result[j].Path })
	return result, nil
}

func expandRoot(path string) (string, error) {
	if path == "" {
		return "", errors.New("empty project root")
	}
	if path == "~" || strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolve home for project root %q: %w", path, err)
		}
		if home == "" {
			return "", fmt.Errorf("resolve home for project root %q: empty home directory", path)
		}
		path = filepath.Join(home, strings.TrimPrefix(path, "~/"))
	}
	absolute, err := filepath.Abs(path)
	if err != nil {
		return "", fmt.Errorf("resolve project root %q: %w", path, err)
	}
	return absolute, nil
}

// MatchSession returns a unique Rex session and window only when a terminal
// block reports exactly this project's canonical cwd. Basenames and labels are
// not identities. Multiple matching sessions (or windows without an active
// matching window) are ambiguous and must instead trigger explicit-cwd creation.
func MatchSession(project Project, sessions []rex.SessionDetail) (sessionID, windowID string, ok bool) {
	path, err := canonicalDirectory(project.Path)
	if err != nil {
		return "", "", false
	}
	for _, session := range sessions {
		matchingWindows := make(map[string]bool)
		for _, window := range session.Windows {
			if window.ID == "" {
				continue
			}
			for _, block := range window.Blocks {
				if block.Creator != "com.superlogical.terminal" || block.CWD == "" {
					continue
				}
				cwd, err := canonicalDirectory(block.CWD)
				if err == nil && cwd == path {
					matchingWindows[window.ID] = true
				}
			}
		}
		if len(matchingWindows) == 0 {
			continue
		}
		if session.ID == "" || sessionID != "" {
			return "", "", false
		}
		sessionID = session.ID
		if matchingWindows[session.ActiveWindowID] {
			windowID = session.ActiveWindowID
		} else if len(matchingWindows) == 1 {
			for id := range matchingWindows {
				windowID = id
			}
		} else {
			return "", "", false
		}
	}
	return sessionID, windowID, sessionID != "" && windowID != ""
}

func canonicalDirectory(path string) (string, error) {
	if !filepath.IsAbs(path) {
		return "", errors.New("directory must be absolute")
	}
	path, err := filepath.EvalSymlinks(filepath.Clean(path))
	if err != nil {
		return "", err
	}
	info, err := os.Stat(path)
	if err != nil {
		return "", err
	}
	if !info.IsDir() {
		return "", errors.New("not a directory")
	}
	return path, nil
}
