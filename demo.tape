# vhs demo.tape — regenerates demo.gif (https://github.com/charmbracelet/vhs)
# Expects a demo repo at /tmp/wt-demo/app with a .wt-setup.sh; see the repo's
# release notes or just: any repo with a setup script works.

Output demo.gif

Set Shell zsh
Set FontSize 20
Set Width 1100
Set Height 560
Set Theme "Catppuccin Mocha"
Set TypingSpeed 60ms

Hide
Type "source ~/wt/wt.sh && export WT_ROOT=/tmp/wt-demo/worktrees && cd /tmp/wt-demo/app && PROMPT='%F{magenta}❯%f ' && clear"
Enter
Show

Sleep 800ms
Type "wt feature-x"
Sleep 500ms
Enter
Sleep 2s

Type "wt log feature-x"
Sleep 500ms
Enter
Sleep 3s
Ctrl+C
Sleep 500ms

Type "ls -a"
Sleep 300ms
Enter
Sleep 1.5s

Type "wt main"
Sleep 300ms
Enter
Sleep 800ms

Type "wt rm feature-x"
Sleep 500ms
Enter
Sleep 2.5s
