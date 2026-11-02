// Package rex wraps the Rex CLI without a shell or implicit server startup.
package rex

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"
)

type Config struct {
	Executable, ClientID, Server string
	Timeout                      time.Duration
}
type Client struct{ config Config }

// AppClient is a connected Rex app (not a CLI process).
type AppClient struct {
	ID   string `json:"client_id"`
	Info struct {
		Kind  string `json:"kind"`
		Label string `json:"label"`
	} `json:"info"`
	ConnectionState string `json:"connection_state"`
}
type Session struct {
	ID    string `json:"session_id"`
	Label string `json:"label"`
}
type SessionDetail struct {
	ID             string   `json:"session_id"`
	Label          string   `json:"label"`
	ActiveWindowID string   `json:"active_window_id"`
	Windows        []Window `json:"windows"`
}
type Window struct {
	ID             string  `json:"window_id"`
	FocusedBlockID string  `json:"focused_block_id"`
	Blocks         []Block `json:"blocks"`
	Layers         []struct {
		Blocks []Block `json:"blocks"`
	} `json:"layers"`
}
type Block struct {
	ID      string `json:"block_id"`
	Creator string `json:"creator_name"`
	Label   string `json:"label"`
	// CWD is a Rex-reported, absolute process or OSC-7 terminal path; empty
	// means no trustworthy cwd was available for conservative project matching.
	CWD string `json:"cwd,omitempty"`
}
type Record struct {
	ID      string `json:"id"`
	State   string `json:"state"`
	Kind    string `json:"kind"`
	App     string `json:"app"`
	Title   string `json:"title"`
	Message string `json:"msg"`
}
type Event struct {
	Kind, SessionID, WindowID, BlockID, RecordID string
	Record                                       *Record
	RemovedIDs                                   []string
}

func New(c Config) (*Client, error) {
	if c.Executable == "" {
		return nil, errors.New("rex executable required")
	}
	if c.Timeout <= 0 {
		c.Timeout = 10 * time.Second
	}
	return &Client{config: c}, nil
}
func (c *Client) argv(args ...string) []string {
	a := []string{"--autostart=false", "--color=never", "--timeout", c.config.Timeout.String()}
	if c.config.Server != "" {
		a = append(a, "-S", c.config.Server)
	}
	return append(a, args...)
}
func (c *Client) run(ctx context.Context, args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(ctx, c.config.Timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, c.config.Executable, c.argv(args...)...)
	var out, errout bytes.Buffer
	cmd.Stdout = &cappedWriter{buffer: &out, limit: 1 << 20}
	cmd.Stderr = &cappedWriter{buffer: &errout, limit: 8192}
	err := cmd.Run()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	if err != nil {
		return nil, fmt.Errorf("rex %s: %w: %s", args[0], err, strings.TrimSpace(errout.String()))
	}
	if out.Len() >= 1<<20 {
		return nil, errors.New("rex response exceeds 1 MiB")
	}
	return out.Bytes(), nil
}

// cap both CLI responses and terminal captures, which may contain huge scrollback.
type cappedWriter struct {
	buffer *bytes.Buffer
	limit  int
}

func (w *cappedWriter) Write(p []byte) (int, error) {
	n := len(p)
	remaining := w.limit - w.buffer.Len()
	if remaining > 0 {
		if remaining > len(p) {
			remaining = len(p)
		}
		_, _ = w.buffer.Write(p[:remaining])
	}
	return n, nil
}
func (c *Client) Sessions(ctx context.Context) ([]Session, error) {
	b, e := c.run(ctx, "ls", "--json")
	if e != nil {
		return nil, e
	}
	var v struct {
		Sessions []Session `json:"sessions"`
	}
	e = json.Unmarshal(b, &v)
	return v.Sessions, e
}
func (c *Client) Inspect(ctx context.Context, id string) (SessionDetail, error) {
	var v SessionDetail
	if id == "" || strings.HasPrefix(id, "-") {
		return v, errors.New("invalid session ID")
	}
	b, e := c.run(ctx, "session", "inspect", id, "--json")
	if e != nil {
		return v, e
	}
	e = json.Unmarshal(b, &v)
	if e != nil {
		return v, e
	}
	for i := range v.Windows {
		for _, l := range v.Windows[i].Layers {
			v.Windows[i].Blocks = append(v.Windows[i].Blocks, l.Blocks...)
		}
		for j := range v.Windows[i].Blocks {
			block := &v.Windows[i].Blocks[j]
			if block.Creator != "com.superlogical.terminal" {
				block.CWD = ""
				continue
			}
			block.CWD, _ = normalizeCWD(block.CWD)
			if block.CWD == "" && block.ID != "" {
				block.CWD, _ = c.BlockCWD(ctx, v.ID, block.ID)
			}
		}
	}
	return v, nil
}

// BlockCWD asks Rex for the foreground process's current directory. If that
// is unavailable, it uses the terminal's last OSC-7 pwd report. Neither source
// is guessed from labels or inherited picker environment. Relative paths and
// nonlocal file URLs are rejected rather than reused for project identity.
func (c *Client) BlockCWD(ctx context.Context, sessionID, blockID string) (string, error) {
	if sessionID == "" || blockID == "" || strings.HasPrefix(sessionID, "-") || strings.HasPrefix(blockID, "-") {
		return "", errors.New("invalid session or block ID")
	}
	b, processErr := c.run(ctx, "block", "call", "-s", sessionID, "-b", blockID, "process")
	if processErr == nil {
		var v struct {
			Foreground *struct {
				CWD string `json:"cwd"`
			} `json:"foreground"`
		}
		if e := json.Unmarshal(b, &v); e != nil {
			processErr = e
		} else if v.Foreground != nil {
			if cwd, _ := normalizeCWD(v.Foreground.CWD); cwd != "" {
				return cwd, nil
			}
		}
	}
	b, pwdErr := c.run(ctx, "block", "call", "-s", sessionID, "-b", blockID, "pwd")
	if pwdErr != nil {
		if processErr != nil {
			return "", fmt.Errorf("rex process: %v; pwd: %w", processErr, pwdErr)
		}
		return "", pwdErr
	}
	var v struct {
		PWD string `json:"pwd"`
	}
	if e := json.Unmarshal(b, &v); e != nil {
		return "", e
	}
	return normalizeCWD(v.PWD)
}

// normalizeCWD makes process and OSC-7 cwd comparable to canonical project
// paths. Unavailable/deleted/non-directory paths cannot justify session reuse.
func normalizeCWD(path string) (string, error) {
	if strings.HasPrefix(path, "file:") {
		u, e := url.Parse(path)
		if e != nil || u.Scheme != "file" || (u.Host != "" && u.Host != "localhost") {
			return "", errors.New("nonlocal or invalid terminal pwd URL")
		}
		path = u.Path
	}
	if !filepath.IsAbs(path) {
		return "", nil
	}
	canonical, e := filepath.EvalSymlinks(filepath.Clean(path))
	if e != nil {
		return "", nil
	}
	info, e := os.Stat(canonical)
	if e != nil || !info.IsDir() {
		return "", nil
	}
	return canonical, nil
}
func (c *Client) Status(ctx context.Context, s, b string) ([]Record, error) {
	out, e := c.run(ctx, "block", "call", "-s", s, "-b", b, "program_status")
	if e != nil {
		return nil, e
	}
	var v struct {
		Records []Record `json:"records"`
	}
	e = json.Unmarshal(out, &v)
	return v.Records, e
}
func (c *Client) Capture(ctx context.Context, s, b string) (string, error) {
	out, e := c.run(ctx, "capture", "-s", s, "-b", b, "--trim", "--unwrap")
	return Sanitize(string(out)), e
}
func (c *Client) NewSession(ctx context.Context, label, cwd string) (SessionDetail, error) {
	var v SessionDetail
	if cwd == "" {
		return v, errors.New("explicit cwd required")
	}
	if strings.HasPrefix(label, "-") {
		return v, errors.New("session label cannot start with a flag prefix")
	}
	b, e := c.run(ctx, "new", label, "--cwd", cwd, "--json")
	if e != nil {
		return v, e
	}
	var result struct {
		ID             string `json:"session_id"`
		InitialWindows []struct {
			ID     string   `json:"window_id"`
			Blocks []string `json:"block_ids"`
		} `json:"initial_windows"`
	}
	if e = json.Unmarshal(b, &result); e != nil {
		return v, e
	}
	if result.ID == "" {
		return v, errors.New("rex new returned no session_id")
	}
	v.ID = result.ID
	v.Label = label
	for _, w := range result.InitialWindows {
		win := Window{ID: w.ID}
		for _, id := range w.Blocks {
			win.Blocks = append(win.Blocks, Block{ID: id})
		}
		v.Windows = append(v.Windows, win)
	}
	if len(v.Windows) > 0 {
		v.ActiveWindowID = v.Windows[0].ID
	}
	return v, nil
}

// AppClients excludes CLI clients and disconnected app connections.
func (c *Client) AppClients(ctx context.Context) ([]AppClient, error) {
	b, e := c.run(ctx, "client", "ls", "--json")
	if e != nil {
		return nil, e
	}
	var v struct {
		Clients []AppClient `json:"clients"`
	}
	if e = json.Unmarshal(b, &v); e != nil {
		return nil, e
	}
	apps := make([]AppClient, 0)
	for _, a := range v.Clients {
		if a.Info.Kind == "app" && a.ConnectionState == "connected" {
			apps = append(apps, a)
		}
	}
	return apps, nil
}

// ResolveClient accepts an exact ID or label, only if it identifies one app.
// An empty name succeeds only when exactly one connected app exists.
func (c *Client) ResolveClient(ctx context.Context, name string) (string, error) {
	apps, e := c.AppClients(ctx)
	if e != nil {
		return "", e
	}
	var id string
	for _, a := range apps {
		if name == "" || name == a.ID || name == a.Info.Label {
			if id != "" {
				return "", fmt.Errorf("ambiguous Rex app client %q", name)
			}
			id = a.ID
		}
	}
	if id == "" {
		return "", fmt.Errorf("no connected Rex app client matches %q", name)
	}
	return id, nil
}
func (c *Client) Select(ctx context.Context, s, w string) error {
	if c.config.ClientID == "" {
		return errors.New("explicit app client ID required")
	}
	if s == "" {
		return errors.New("session ID required")
	}
	id, e := c.ResolveClient(ctx, c.config.ClientID)
	if e != nil {
		return e
	}
	a := map[string]string{"session_id": s}
	if w != "" {
		a["window_id"] = w
	}
	b, _ := json.Marshal(a)
	_, e = c.run(ctx, "-C", id, "do", "session.select", "--args", string(b))
	return e
}
func (c *Client) FocusBlock(ctx context.Context, s, b string) error {
	if s == "" || b == "" {
		return errors.New("session and block IDs required")
	}
	arg, _ := json.Marshal(map[string]string{"block_id": b})
	_, e := c.run(ctx, "api", "call", "-s", s, "session.focus_block", string(arg))
	return e
}

// Events owns one subprocess. Cancel ctx to interrupt and reap it. Malformed lines are
// reported on the error channel; subsequent valid events are still delivered.
func (c *Client) Events(ctx context.Context) (<-chan Event, <-chan error) {
	events := make(chan Event, 128)
	errs := make(chan error, 16)
	go func() {
		defer close(events)
		defer close(errs)
		cmd := exec.CommandContext(ctx, c.config.Executable, c.argv("events", "--all", "--json")...)
		stdout, e := cmd.StdoutPipe()
		if e != nil {
			errs <- e
			return
		}
		var stderr bytes.Buffer
		cmd.Stderr = &cappedWriter{buffer: &stderr, limit: 8192}
		if e = cmd.Start(); e != nil {
			errs <- e
			return
		}
		scanner := bufio.NewScanner(stdout)
		scanner.Buffer(make([]byte, 4096), 1<<20)
		for scanner.Scan() {
			ev, parseErr := ParseEvent(scanner.Bytes())
			if parseErr != nil {
				offer(errs, parseErr)
			} else if ev.Kind != "" {
				select {
				case events <- ev:
				case <-ctx.Done():
				}
			}
			if ctx.Err() != nil {
				break
			}
		}
		scanErr := scanner.Err()
		if scanErr != nil {
			offer(errs, fmt.Errorf("rex event stream: %w", scanErr))
			// A scanner error (notably an oversized line) stops reading stdout,
			// but `rex events` can keep running indefinitely. Kill it before
			// Wait so the channels close and state.Run can resubscribe.
			if ctx.Err() == nil {
				_ = cmd.Process.Kill()
			}
		}
		e = cmd.Wait()
		if ctx.Err() != nil || scanErr != nil {
			return
		}
		if e != nil {
			offer(errs, fmt.Errorf("rex events: %w: %s", e, strings.TrimSpace(stderr.String())))
		} else {
			offer(errs, io.EOF)
		}
	}()
	return events, errs
}
func offer(ch chan error, e error) {
	select {
	case ch <- e:
	default:
	}
}

// ParseEvent normalizes nested Rex session/block envelopes; unknown types are ignored.
func ParseEvent(line []byte) (Event, error) {
	var v struct {
		Type    string          `json:"type"`
		Payload json.RawMessage `json:"payload"`
	}
	if e := json.Unmarshal(line, &v); e != nil {
		return Event{}, fmt.Errorf("malformed rex event: %w", e)
	}
	if v.Type == "" {
		return Event{}, errors.New("rex event missing type")
	}
	var out Event
	for i := 0; i < 4; i++ {
		var p struct {
			SessionID string          `json:"session_id"`
			WindowID  string          `json:"window_id"`
			BlockID   string          `json:"block_id"`
			ID        string          `json:"id"`
			Record    *Record         `json:"record"`
			IDs       []string        `json:"ids"`
			Event     json.RawMessage `json:"event"`
			Type      string          `json:"type"`
			Name      string          `json:"name"`
			Payload   json.RawMessage `json:"payload"`
		}
		if len(v.Payload) == 0 {
			break
		}
		if e := json.Unmarshal(v.Payload, &p); e != nil {
			return Event{}, fmt.Errorf("malformed rex event payload: %w", e)
		}
		if p.SessionID != "" {
			out.SessionID = p.SessionID
		}
		if p.WindowID != "" {
			out.WindowID = p.WindowID
		}
		if p.BlockID != "" {
			out.BlockID = p.BlockID
		}
		if p.Name != "" {
			out.Kind = p.Name
		}
		if p.Record != nil {
			out.Record = p.Record
			out.RecordID = p.ID
			out.Record.ID = p.ID
		}
		if p.IDs != nil {
			out.RemovedIDs = p.IDs
		}
		if len(p.Event) > 0 {
			if e := json.Unmarshal(p.Event, &v); e != nil {
				return Event{}, e
			}
			continue
		}
		if p.Type != "" {
			v.Type = p.Type
		}
		if len(p.Payload) > 0 {
			v.Payload = p.Payload
			continue
		}
		break
	}
	if out.Kind == "" {
		out.Kind = v.Type
	}
	return out, nil
}

// Sanitize strips terminal controls (including OSC and CSI), preserving printable text.
func Sanitize(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); {
		r, n := utf8.DecodeRuneInString(s[i:])
		i += n
		// Invalid single-byte C1 sequences can occur in terminal captures.
		if r == utf8.RuneError && n == 1 && s[i-1] == 0x9b {
			for i < len(s) {
				x := s[i]
				i++
				if x >= 0x40 && x <= 0x7e {
					break
				}
			}
			continue
		}
		if r == 0x1b {
			if i >= len(s) {
				break
			}
			switch s[i] {
			case '[':
				i++
				for i < len(s) {
					x := s[i]
					i++
					if x >= 0x40 && x <= 0x7e {
						break
					}
				}
			case ']', 'P', '_', '^', 'X':
				i++
				for i < len(s) {
					if s[i] == 7 {
						i++
						break
					}
					if s[i] == 0x1b && i+1 < len(s) && s[i+1] == '\\' {
						i += 2
						break
					}
					i++
				}
			default:
				_, n = utf8.DecodeRuneInString(s[i:])
				i += n
			}
			continue
		}
		if r == 0x9b {
			for i < len(s) {
				x := s[i]
				i++
				if x >= 0x40 && x <= 0x7e {
					break
				}
			}
			continue
		}
		if r == 0x9d || r == 0x90 || r == 0x9f {
			for i < len(s) {
				x, n := utf8.DecodeRuneInString(s[i:])
				i += n
				if x == 7 || x == 0x9c {
					break
				}
			}
			continue
		}
		if (r < 32 && r != '\n' && r != '\t') || (r >= 0x7f && r <= 0x9f) || r == utf8.RuneError {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}
