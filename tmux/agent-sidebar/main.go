package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle    = lipgloss.NewStyle().Bold(true)
	projectStyle  = lipgloss.NewStyle().Bold(true).PaddingTop(1)
	selectedStyle = lipgloss.NewStyle().Reverse(true)
	attnStyle     = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("1"))
	busyStyle     = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("4"))
	doneStyle     = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("2"))
	dimStyle      = lipgloss.NewStyle().Faint(true)
)

type agent struct {
	project     string
	state       string
	session     string
	windowIndex string
	paneIndex   string
	paneID      string
	windowName  string
}

type model struct {
	agents   []agent
	selected int
	width    int
	height   int
}

type refreshMsg []agent

func doRefresh() tea.Msg {
	return refreshMsg(fetchAgents())
}

func tickCmd() tea.Cmd {
	return tea.Tick(3*time.Second, func(time.Time) tea.Msg {
		return doRefresh()
	})
}

func (m model) Init() tea.Cmd {
	return tea.Batch(doRefresh, tickCmd())
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.KeyMsg:
		switch msg.String() {
		case "j", "down":
			if m.selected < len(m.agents)-1 {
				m.selected++
			}
		case "k", "up":
			if m.selected > 0 {
				m.selected--
			}
		case "g", "home":
			m.selected = 0
		case "G", "end":
			if len(m.agents) > 0 {
				m.selected = len(m.agents) - 1
			}
		case "enter":
			if len(m.agents) > 0 && m.selected < len(m.agents) {
				a := m.agents[m.selected]
				exec.Command("tmux", "switch-client", "-t", a.session).Run()
				exec.Command("tmux", "select-window", "-t", a.session+":"+a.windowIndex).Run()
				exec.Command("tmux", "select-pane", "-t", a.paneID).Run()
			}
		case "q", "ctrl+c":
			return m, tea.Quit
		}

	case refreshMsg:
		m.agents = []agent(msg)
		if m.selected >= len(m.agents) {
			m.selected = max(0, len(m.agents)-1)
		}
		return m, tickCmd()

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	}

	return m, nil
}

func (m model) View() string {
	var b strings.Builder

	b.WriteString(titleStyle.Render("Agents"))
	b.WriteString("\n")

	if len(m.agents) == 0 {
		b.WriteString("\n")
		b.WriteString(dimStyle.Render("No agents"))
		b.WriteString("\n")
		return b.String()
	}

	currentProject := ""
	for i, a := range m.agents {
		if a.project != currentProject {
			b.WriteString(projectStyle.Render(a.project))
			b.WriteString("\n")
			currentProject = a.project
		}

		// State label
		var stateText string
		switch a.state {
		case "attention":
			stateText = "! ATTN"
		case "done":
			stateText = "+ DONE"
		default:
			stateText = "~ BUSY"
		}

		// Display label
		label := a.windowName
		if label == "" || label == "zsh" || label == "bash" {
			label = fmt.Sprintf("%s:%s.%s", a.session, a.windowIndex, a.paneIndex)
		}

		if i == m.selected {
			line := fmt.Sprintf(" ▸ %s  %s", stateText, label)
			b.WriteString(selectedStyle.Width(m.width).Render(line))
		} else {
			var coloredState string
			switch a.state {
			case "attention":
				coloredState = attnStyle.Render(stateText)
			case "done":
				coloredState = doneStyle.Render(stateText)
			default:
				coloredState = busyStyle.Render(stateText)
			}
			b.WriteString(fmt.Sprintf("   %s  %s", coloredState, label))
		}
		b.WriteString("\n")
	}

	return b.String()
}

// fetchAgents gets all tracked agent panes from tmux in minimal commands.
func fetchAgents() []agent {
	// 1. Get all agent_notify options in one call
	optOut, err := exec.Command("tmux", "show-options", "-g").Output()
	if err != nil {
		return nil
	}

	paneList := ""
	states := map[string]string{}

	for _, line := range strings.Split(string(optOut), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "@agent_notify_all_panes ") {
			paneList = strings.TrimPrefix(line, "@agent_notify_all_panes ")
			paneList = strings.Trim(paneList, "\"")
		} else if strings.HasPrefix(line, "@agent_notify_state_") {
			parts := strings.SplitN(line, " ", 2)
			if len(parts) == 2 {
				suffix := strings.TrimPrefix(parts[0], "@agent_notify_state_")
				states[suffix] = strings.Trim(parts[1], "\"")
			}
		}
	}

	paneList = strings.TrimSpace(paneList)
	if paneList == "" {
		return nil
	}
	paneIDs := strings.Fields(paneList)

	// 2. Get all pane info in one call
	paneInfoOut, err := exec.Command("tmux", "list-panes", "-a",
		"-F", "#{pane_id}|#{session_name}|#{window_index}|#{window_name}|#{pane_index}|#{pane_current_path}").Output()
	if err != nil {
		return nil
	}

	paneInfoMap := map[string]string{}
	for _, line := range strings.Split(string(paneInfoOut), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "|", 2)
		if len(parts) == 2 {
			paneInfoMap[parts[0]] = line
		}
	}

	// 3. Build agent list
	tracked := map[string]bool{}
	for _, id := range paneIDs {
		tracked[id] = true
	}

	var agents []agent
	for _, paneID := range paneIDs {
		suffix := strings.TrimPrefix(paneID, "%")
		state := states[suffix]

		info, ok := paneInfoMap[paneID]
		if !ok {
			continue
		}
		parts := strings.SplitN(info, "|", 6)
		if len(parts) < 6 {
			continue
		}

		project := resolveProjectName(parts[5], parts[1])

		agents = append(agents, agent{
			project:     project,
			state:       state,
			session:     parts[1],
			windowIndex: parts[2],
			windowName:  parts[3],
			paneIndex:   parts[4],
			paneID:      paneID,
		})
	}

	sort.Slice(agents, func(i, j int) bool {
		if agents[i].project != agents[j].project {
			return agents[i].project < agents[j].project
		}
		return agents[i].session+agents[i].windowIndex < agents[j].session+agents[j].windowIndex
	})

	return agents
}

func resolveProjectName(path, sessionName string) string {
	out, err := exec.Command("git", "-C", path, "rev-parse", "--path-format=absolute", "--git-common-dir").Output()
	if err == nil {
		gitDir := strings.TrimSpace(string(out))
		return filepath.Base(filepath.Dir(gitDir))
	}

	home, _ := os.UserHomeDir()
	if path == home || path == home+"/" {
		return sessionName
	}

	if path != "" && path != "/" {
		return filepath.Base(path)
	}

	return sessionName
}

func main() {
	p := tea.NewProgram(model{}, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
