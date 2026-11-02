package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/pperanich/rexpick/internal/projects"
	"github.com/pperanich/rexpick/internal/rex"
	"github.com/pperanich/rexpick/internal/state"
	"github.com/pperanich/rexpick/internal/ui"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "rexpick:", err)
		os.Exit(1)
	}
}
func run(args []string) error {
	flags := flag.NewFlagSet("rexpick", flag.ContinueOnError)
	executable := flags.String("rex", env("REXPICK_REX", "rex"), "path to Rex CLI executable")
	clientName := flags.String("client", os.Getenv("REXPICK_CLIENT"), "connected Rex app client ID or unique label (required if multiple apps)")
	server := flags.String("server", os.Getenv("REXPICK_SERVER"), "Rex server address (default: Rex CLI default; no autostart)")
	roots := flags.String("roots", os.Getenv("REXPICK_ROOTS"), "comma-separated project roots, optionally with :depth (default: tms roots)")
	if err := flags.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return nil
		}
		return err
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("unexpected arguments: %v", flags.Args())
	}
	path, err := exec.LookPath(*executable)
	if err != nil {
		return fmt.Errorf("rex executable %q: %w", *executable, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	probe, err := rex.New(rex.Config{Executable: path, Server: *server})
	if err != nil {
		return err
	}
	appID, err := probe.ResolveClient(ctx, *clientName)
	if err != nil {
		return err
	}
	backend, err := rex.New(rex.Config{Executable: path, ClientID: appID, Server: *server})
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	projectRoots, err := parseRoots(*roots, home)
	if err != nil {
		return err
	}
	found, err := projects.Discover(ctx, projectRoots)
	if err != nil {
		return fmt.Errorf("discover projects: %w", err)
	}
	snapshot := state.New()
	notices := make(chan error, 64)
	done := make(chan struct{})
	go func() { defer close(done); defer close(notices); state.Run(ctx, backend, snapshot, notices) }()
	final, err := tea.NewProgram(ui.New(ctx, backend, snapshot, found, notices), tea.WithAltScreen()).Run()
	cancel()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		return errors.New("Rex subscription did not stop after exit")
	}
	if err != nil {
		return err
	}
	if model, ok := final.(ui.Model); ok {
		return model.ActionError()
	}
	return errors.New("picker exited without a UI model")
}
func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
func parseRoots(spec, home string) ([]projects.Root, error) {
	if spec == "" {
		return projects.DefaultRoots(home), nil
	}
	var result []projects.Root
	for _, v := range strings.Split(spec, ",") {
		v = strings.TrimSpace(v)
		if v == "" {
			return nil, errors.New("empty project root")
		}
		root := projects.Root{Path: v, Depth: 2}
		if prefix, depth, ok := strings.Cut(v, ":"); ok {
			var n int
			if _, err := fmt.Sscanf(depth, "%d", &n); err != nil || n < 0 || n > 32 || fmt.Sprint(n) != depth {
				return nil, fmt.Errorf("invalid root depth %q", depth)
			}
			root = projects.Root{Path: prefix, Depth: n}
		}
		if root.Path == "" {
			return nil, errors.New("empty project root path")
		}
		result = append(result, root)
	}
	return result, nil
}
