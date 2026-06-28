// Command claude-ps reports how many Claude Code sessions are running on
// this machine, and how many are working vs waiting for input.
//
//	claude-ps              human-readable: summary + per-session list
//	claude-ps --watch      live-refreshing monitor (for the floating popup)
//	claude-ps --count      just the total number (for scripts / prompts)
//	claude-ps --tmux       compact one-liner for the tmux status bar
//	claude-ps --json       machine output (counts + per-session detail)
//	claude-ps --noctalia   JSON for the Noctalia CustomButton widget
//
// A Claude Code session is a process whose /proc/<pid>/comm is exactly
// "claude" (one per open terminal). The MCP/sidecar "server" binaries
// under /tmp/claude-*/go-build*/exe/server are NOT sessions and are
// excluded by the strict comm match.
//
// Working vs waiting is read from the terminal title, the same signal the
// tmux status bar uses (see dotfiles/tmux/tmux.conf @agent-state): Claude
// shows a "✳ <name>" title while idle and an animated braille spinner
// ("⠐ <name>", "⠂ <name>", …) while the agent is working. We map each
// session PID to its pseudo-terminal, then to the matching tmux pane's
// title. Sessions whose tty isn't owned by a visible tmux pane (e.g. run
// outside tmux) are reported as "unknown" state — counted, but not
// classified.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// USER_HZ is the kernel clock-tick rate used for /proc starttime. It is
// 100 on every mainstream Linux build; sysconf(_SC_CLK_TCK) isn't exposed
// without cgo, so we hardcode the universal value.
const userHZ = 100.0

type state int

const (
	stateUnknown state = iota
	stateWaiting
	stateWorking
)

func (s state) emoji() string {
	switch s {
	case stateWorking:
		return "🔄"
	case stateWaiting:
		return "✅"
	default:
		return "·"
	}
}

func (s state) String() string {
	switch s {
	case stateWorking:
		return "working"
	case stateWaiting:
		return "waiting"
	default:
		return "unknown"
	}
}

type session struct {
	PID     int    `json:"pid"`
	Cwd     string `json:"cwd"`
	Project string `json:"project"` // short, home-relative project label
	Name    string `json:"name"`    // session title with the state marker stripped
	State   string `json:"state"`   // "working" | "waiting" | "unknown"
	Age     int    `json:"age_seconds"`

	st state // unexported, for sorting/counting
}

func main() {
	switch {
	case hasFlag("--watch"):
		watch()
	case hasFlag("--count"):
		fmt.Println(len(claudePIDs())) // bare count: no tmux/proc classification needed
	case hasFlag("--tmux"):
		emitTmux(collect())
	case hasFlag("--json"):
		emitJSON(collect())
	case hasFlag("--noctalia"):
		emitNoctalia(collect())
	default:
		emitHuman(collect())
	}
}

// watch redraws the human-readable view on the alternate screen every 2s
// until interrupted — the live monitor opened by the Noctalia click.
func watch() {
	fmt.Print("\033[?1049h\033[?25l")       // alt screen, hide cursor
	defer fmt.Print("\033[?25h\033[?1049l") // restore on a clean exit

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	tick := time.NewTicker(2 * time.Second)
	defer tick.Stop()

	for {
		fmt.Print("\033[H\033[2J") // home + clear
		emitHuman(collect())
		fmt.Print("\n\033[2m↻ refreshing every 2s · Ctrl-C to close\033[0m\n")
		select {
		case <-stop:
			fmt.Print("\033[?25h\033[?1049l")
			return
		case <-tick.C:
		}
	}
}

func hasFlag(f string) bool {
	for _, a := range os.Args[1:] {
		if a == f {
			return true
		}
	}
	return false
}

// collect enumerates Claude Code sessions and classifies each one.
func collect() []session {
	titles := paneTitles() // pts path -> tmux pane title
	uptime := uptimeSeconds()

	var out []session
	for _, pid := range claudePIDs() {
		cwd, _ := os.Readlink(procPath(pid, "cwd"))
		title := titles[ttyOf(pid)]
		st, name := classify(title)

		out = append(out, session{
			PID:     pid,
			Cwd:     cwd,
			Project: shortLabel(cwd),
			Name:    name,
			State:   st.String(),
			Age:     ageSeconds(pid, uptime),
			st:      st,
		})
	}

	// Working first, then waiting, then unknown; oldest first within a group.
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].st != out[j].st {
			return out[i].st > out[j].st
		}
		return out[i].Age > out[j].Age
	})
	return out
}

// claudePIDs returns PIDs whose comm is exactly "claude".
func claudePIDs() []int {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return nil
	}
	var pids []int
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil {
			continue
		}
		comm, err := os.ReadFile(procPath(pid, "comm"))
		if err != nil {
			continue // process vanished or unreadable
		}
		if strings.TrimSpace(string(comm)) == "claude" {
			pids = append(pids, pid)
		}
	}
	sort.Ints(pids)
	return pids
}

// ttyOf returns the /dev/pts/N controlling terminal of a process, or "".
func ttyOf(pid int) string {
	for _, fd := range []string{"0", "1", "2"} {
		if target, err := os.Readlink(procPath(pid, "fd", fd)); err == nil {
			if strings.HasPrefix(target, "/dev/pts/") {
				return target
			}
		}
	}
	return ""
}

// paneTitles maps each tmux pane's tty to its title. Empty if no server.
func paneTitles() map[string]string {
	out, err := exec.Command("tmux", "list-panes", "-a",
		"-F", "#{pane_tty}\t#{pane_title}").Output()
	if err != nil {
		return map[string]string{}
	}
	m := map[string]string{}
	for _, line := range strings.Split(strings.TrimRight(string(out), "\n"), "\n") {
		tty, title, ok := strings.Cut(line, "\t")
		if ok {
			m[tty] = title
		}
	}
	return m
}

// classify replicates the tmux @agent-state rule: a "✳…" title or one
// that starts with a plain path/word means idle; anything else (a leading
// braille spinner) means working. Returns the state and the title with its
// leading marker rune stripped for display.
func classify(title string) (state, string) {
	title = strings.TrimSpace(title)
	if title == "" {
		return stateUnknown, ""
	}
	first := []rune(title)[0]
	idle := first == '✳' || isPlainStart(first)
	st := stateWorking
	if idle {
		st = stateWaiting
	}
	return st, stripMarker(title)
}

func isPlainStart(r rune) bool {
	return r == '~' || r == '/' ||
		(r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9')
}

// stripMarker drops a leading status marker (the "✳" idle glyph or a
// braille working spinner) plus its following space, leaving the bare
// session name. A marker is exactly the leading rune classify() keys on:
// any non-plain start, so both functions share the isPlainStart predicate.
func stripMarker(title string) string {
	r := []rune(title)
	if len(r) > 1 && r[1] == ' ' && !isPlainStart(r[0]) {
		return strings.TrimSpace(string(r[2:]))
	}
	return title
}

func shortLabel(cwd string) string {
	if cwd == "" {
		return "(unknown)"
	}
	if home, err := os.UserHomeDir(); err == nil && strings.HasPrefix(cwd, home) {
		cwd = "~" + cwd[len(home):]
	}
	parts := strings.FieldsFunc(cwd, func(r rune) bool { return r == '/' })
	parts = trimTilde(parts)
	if len(parts) > 2 {
		parts = parts[len(parts)-2:]
	}
	if len(parts) == 0 {
		return cwd
	}
	return strings.Join(parts, "/")
}

func trimTilde(parts []string) []string {
	for len(parts) > 0 && parts[0] == "~" {
		parts = parts[1:]
	}
	return parts
}

// ageSeconds derives a process's age from its /proc starttime and uptime.
func ageSeconds(pid int, uptime float64) int {
	data, err := os.ReadFile(procPath(pid, "stat"))
	if err != nil {
		return 0
	}
	// comm (field 2) may contain spaces/parens; fields after the last ')'
	// are clean and space-separated. starttime is field 22 overall, i.e.
	// index 19 of the post-comm slice (which starts at field 3).
	s := string(data)
	rest := s[strings.LastIndexByte(s, ')')+1:]
	fields := strings.Fields(rest)
	if len(fields) < 20 {
		return 0
	}
	startTicks, err := strconv.ParseFloat(fields[19], 64)
	if err != nil {
		return 0
	}
	age := uptime - startTicks/userHZ
	if age < 0 {
		return 0
	}
	return int(age)
}

func uptimeSeconds() float64 {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return 0
	}
	f, _ := strconv.ParseFloat(strings.Fields(string(data))[0], 64)
	return f
}

func procPath(pid int, parts ...string) string {
	return filepath.Join(append([]string{"/proc", strconv.Itoa(pid)}, parts...)...)
}

func tally(sessions []session) (working, waiting, unknown int) {
	for _, s := range sessions {
		switch s.st {
		case stateWorking:
			working++
		case stateWaiting:
			waiting++
		default:
			unknown++
		}
	}
	return
}

func fmtAge(seconds int) string {
	d := seconds / 86400
	h := (seconds % 86400) / 3600
	m := (seconds % 3600) / 60
	switch {
	case d > 0:
		return fmt.Sprintf("%dd%dh", d, h)
	case h > 0:
		return fmt.Sprintf("%dh%dm", h, m)
	default:
		return fmt.Sprintf("%dm", m)
	}
}

// statusSummary renders the shared working/waiting (·unknown) breakdown.
func statusSummary(working, waiting, unknown int) string {
	s := fmt.Sprintf("🔄 %d working · ✅ %d waiting", working, waiting)
	if unknown > 0 {
		s += fmt.Sprintf(" · %d unknown", unknown)
	}
	return s
}

func emitHuman(sessions []session) {
	working, waiting, unknown := tally(sessions)
	word := "sessions"
	if len(sessions) == 1 {
		word = "session"
	}
	fmt.Printf("%d Claude Code %s running  —  %s\n",
		len(sessions), word, statusSummary(working, waiting, unknown))
	if len(sessions) == 0 {
		return
	}
	fmt.Println()

	// Column widths.
	nameW, projW := 0, 0
	for _, s := range sessions {
		nameW = max(nameW, len([]rune(s.Name)))
		projW = max(projW, len([]rune(s.Project)))
	}
	for _, s := range sessions {
		fmt.Printf("  %s  %-*s  %-*s  %s\n",
			s.st.emoji(), nameW, s.Name, projW, s.Project, fmtAge(s.Age))
	}
}

// emitTmux prints a compact, single-line summary for the tmux status bar,
// e.g. "🔄 2 ✅ 18" (plus " ❔ N" when some sessions can't be classified).
// Total = working + waiting + unknown.
func emitTmux(sessions []session) {
	working, waiting, unknown := tally(sessions)
	out := fmt.Sprintf("🔄 %d ✅ %d", working, waiting)
	if unknown > 0 {
		out += fmt.Sprintf(" ❔ %d", unknown)
	}
	fmt.Print(out)
}

func emitJSON(sessions []session) {
	working, waiting, unknown := tally(sessions)
	out := map[string]any{
		"count":    len(sessions),
		"working":  working,
		"waiting":  waiting,
		"unknown":  unknown,
		"sessions": sessions,
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	enc.Encode(out)
}

// emitNoctalia prints the JSON shape the Noctalia CustomButton expects
// (parseJson: true): text shown in the bar, tooltip, and textColor.
func emitNoctalia(sessions []session) {
	working, waiting, unknown := tally(sessions)
	text := fmt.Sprintf("%d/%d", working, len(sessions))

	var b strings.Builder
	fmt.Fprintf(&b, "%d Claude Code sessions\n%s",
		len(sessions), statusSummary(working, waiting, unknown))
	for _, s := range sessions {
		fmt.Fprintf(&b, "\n%s %s — %s (%s)", s.st.emoji(), s.Name, s.Project, fmtAge(s.Age))
	}

	color := "none"
	if working > 0 {
		color = "primary"
	}

	json.NewEncoder(os.Stdout).Encode(map[string]string{
		"text":      text,
		"tooltip":   b.String(),
		"textColor": color,
	})
}
