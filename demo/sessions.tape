# prefix f: recorrer las ventanas en el preview, filtrar y entrar a una ventana
Output assets/sessions.gif
Source demo/common.tape

Hide
Type "bash demo/setup.sh && clear && tmux -L kh-demo attach -t api" Enter
Sleep 2s
Show

Sleep 1s
Ctrl+B
Type "f"
Sleep 1.5s
Right
Sleep 1.2s
Right
Sleep 2s
Screenshot assets/sessions.png
Type "web"
Sleep 1s
Right
Sleep 1.5s
Enter
Sleep 2.5s

Hide
Type "tmux -L kh-demo kill-server" Enter
