# prefix g: fuzzy search de texto en todos los panes y salto a la línea
Output assets/search.gif
Source demo/common.tape

Hide
Type "bash demo/setup.sh && clear && tmux -L kh-demo attach -t api" Enter
Sleep 2s
Show

Sleep 1s
Ctrl+B
Type "g"
Sleep 1.2s
Type "reutilizado"
Sleep 2s
Screenshot assets/search.png
Enter
Sleep 3s
Type "q"
Sleep 1s

Hide
Type "tmux -L kh-demo kill-server" Enter
