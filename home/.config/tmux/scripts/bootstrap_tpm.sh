#!/bin/bash
if [ ! -d "$XDG_DATA_HOME/tmux/plugins/tpm/" ]; then
	echo "Cloning TPM..."
	git clone https://github.com/tmux-plugins/tpm "$XDG_DATA_HOME/tmux/plugins/tpm/"
fi
