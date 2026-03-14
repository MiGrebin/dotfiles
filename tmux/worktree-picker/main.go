package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	titleStyle    = lipgloss.NewStyle().Bold(true).PaddingBottom(1)
	inputStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("4"))
	selectedStyle = lipgloss.NewStyle().Reverse(true)
	openStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("2"))
	dimStyle      = lipgloss.NewStyle().Faint(true)
	newStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("3")).Italic(true)
	hintStyle     = lipgloss.NewStyle().Faint(true).PaddingTop(1)
)

type worktree struct {
	name      string
	hasWindow bool
}

type model struct {
	worktrees      []worktree
	filtered       []worktree
	input          string
	selected       int
	width          int
	height         int
	projectRoot    string
	err            error
	confirmDelete  string // name of worktree pending deletion
}

func loadWorktrees(projectRoot string) []worktree {
	worktreeDir := filepath.Join(projectRoot, ".worktrees")
	entries, _ := os.ReadDir(worktreeDir)

	sessionOut, _ := exec.Command("tmux", "display-message", "-p", "#{session_name}").Output()
	session := strings.TrimSpace(string(sessionOut))

	windowsOut, _ := exec.Command("tmux", "list-windows", "-t", session, "-F", "#{window_name}").Output()
	windowNames := map[string]bool{}
	for _, name := range strings.Split(string(windowsOut), "\n") {
		name = strings.TrimSpace(name)
		if name != "" {
			windowNames[name] = true
		}
	}

	var worktrees []worktree
	for _, entry := range entries {
		if entry.IsDir() {
			name := entry.Name()
			worktrees = append(worktrees, worktree{
				name:      name,
				hasWindow: windowNames[name],
			})
		}
	}
	return worktrees
}

func initialModel() model {
	cwd, _ := os.Getwd()

	gitCommonOut, err := exec.Command("git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir").Output()
	if err != nil {
		return model{err: fmt.Errorf("not in a git repository")}
	}
	projectRoot := filepath.Dir(strings.TrimSpace(string(gitCommonOut)))

	m := model{
		worktrees:   loadWorktrees(projectRoot),
		projectRoot: projectRoot,
	}
	m.filtered = m.applyFilter()
	return m
}

func (m model) applyFilter() []worktree {
	if m.input == "" {
		return m.worktrees
	}
	lower := strings.ToLower(m.input)
	var filtered []worktree
	for _, wt := range m.worktrees {
		if strings.Contains(strings.ToLower(wt.name), lower) {
			filtered = append(filtered, wt)
		}
	}
	return filtered
}

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case tea.KeyMsg:
		// Confirmation dialog intercepts all keys
		if m.confirmDelete != "" {
			switch msg.String() {
			case "y", "Y", "enter":
				name := m.confirmDelete
				m.confirmDelete = ""
				// Close tmux window if open
				sessionOut, _ := exec.Command("tmux", "display-message", "-p", "#{session_name}").Output()
				session := strings.TrimSpace(string(sessionOut))
				exec.Command("tmux", "kill-window", "-t", session+":="+name).Run()
				// Remove git worktree (try git first, fall back to rm)
				worktreePath := filepath.Join(m.projectRoot, ".worktrees", name)
				if err := exec.Command("git", "-C", m.projectRoot, "worktree", "remove", worktreePath, "--force").Run(); err != nil {
					os.RemoveAll(worktreePath)
					exec.Command("git", "-C", m.projectRoot, "worktree", "prune").Run()
				}
				// Rebuild list
				m.worktrees = loadWorktrees(m.projectRoot)
				m.filtered = m.applyFilter()
				m.clampSelected()
			default:
				m.confirmDelete = ""
			}
			return m, nil
		}

		switch msg.String() {
		case "ctrl+c", "esc":
			return m, tea.Quit

		case "up", "ctrl+k":
			if m.selected > 0 {
				m.selected--
			}

		case "down", "ctrl+j":
			max := len(m.filtered)
			if m.showCreateOption() {
				max++
			}
			if m.selected < max-1 {
				m.selected++
			}

		case "enter":
			var name string
			if m.showCreateOption() && m.selected == len(m.filtered) {
				name = m.input
			} else if m.selected < len(m.filtered) {
				name = m.filtered[m.selected].name
			}

			if name != "" {
				home, _ := os.UserHomeDir()
				script := filepath.Join(home, "dotfiles/tmux/scripts/worktree_dev.sh")
				exec.Command(script, name, m.projectRoot).Run()
				return m, tea.Quit
			}

		case "ctrl+x":
			if m.selected < len(m.filtered) {
				m.confirmDelete = m.filtered[m.selected].name
			}

		case "backspace":
			if len(m.input) > 0 {
				m.input = m.input[:len(m.input)-1]
				m.filtered = m.applyFilter()
				m.clampSelected()
			}

		default:
			// Regular character input
			s := msg.String()
			if len(s) == 1 && s[0] >= 32 && s[0] <= 126 {
				m.input += s
				m.filtered = m.applyFilter()
				m.clampSelected()
			}
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	}

	return m, nil
}

// showCreateOption returns true if the input doesn't exactly match any worktree.
func (m model) showCreateOption() bool {
	if m.input == "" {
		return false
	}
	for _, wt := range m.worktrees {
		if wt.name == m.input {
			return false
		}
	}
	return true
}

func (m *model) clampSelected() {
	max := len(m.filtered)
	if m.showCreateOption() {
		max++
	}
	if max == 0 {
		m.selected = 0
	} else if m.selected >= max {
		m.selected = max - 1
	}
}

func (m model) View() string {
	if m.err != nil {
		return fmt.Sprintf("Error: %v\n", m.err)
	}

	var b strings.Builder

	b.WriteString(titleStyle.Render("Open Worktree"))
	b.WriteString("\n")

	// Input line
	cursor := "█"
	b.WriteString(inputStyle.Render("> "))
	b.WriteString(m.input)
	b.WriteString(cursor)
	b.WriteString("\n\n")

	if len(m.filtered) == 0 && !m.showCreateOption() {
		if m.input == "" {
			b.WriteString(dimStyle.Render("  No worktrees found. Type a name to create one."))
		} else {
			b.WriteString(dimStyle.Render("  No matches."))
		}
		b.WriteString("\n")
	}

	// Worktree list
	for i, wt := range m.filtered {
		var line string
		status := ""
		if wt.hasWindow {
			status = openStyle.Render(" ● open")
		}

		line = fmt.Sprintf("  %s%s", wt.name, status)

		if i == m.selected {
			line = fmt.Sprintf("  %s%s", wt.name, status)
			b.WriteString(selectedStyle.Width(m.width).Render("▸ " + wt.name + status))
		} else {
			b.WriteString(line)
		}
		b.WriteString("\n")
	}

	// "Create new" option
	if m.showCreateOption() {
		idx := len(m.filtered)
		line := fmt.Sprintf("  + Create \"%s\"", m.input)
		if m.selected == idx {
			b.WriteString(selectedStyle.Width(m.width).Render(line))
		} else {
			b.WriteString(newStyle.Render(line))
		}
		b.WriteString("\n")
	}

	if m.confirmDelete != "" {
		deleteWarn := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("1"))
		b.WriteString("\n")
		b.WriteString(deleteWarn.Render(fmt.Sprintf("  Delete \"%s\"? (y/n)", m.confirmDelete)))
		b.WriteString("\n")
	} else {
		b.WriteString(hintStyle.Render("  ↑↓ navigate  ⏎ select  ^x delete  esc quit"))
		b.WriteString("\n")
	}

	return b.String()
}

func main() {
	m := initialModel()
	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
