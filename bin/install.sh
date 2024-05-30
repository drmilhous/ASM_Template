echo "The shell is $SHELL"
if [[ $SHELL == "/bin/bash" ]]; then
	echo "export PATH=\$PATH:\$HOME/ASM_Template/bin/" >> $HOME/.bashrc
	source $HOME/.bashrc
elif [[ $SHELL == "/bin/zsh" ]]; then
	echo "export PATH=\$PATH:\$HOME/ASM_Template/bin/" >> $HOME/.zshrc
	source $HOME/.zshrc
fi