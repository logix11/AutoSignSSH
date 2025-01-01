#!/bin/bash

gen_static() {
	printf "\n--------------------------------------------------------------------------------\n\n"

	echo -e "${INFO}	Generating the key, it'll prompt you for an encryption passphrase."
	if ssh-keygen -a "$1" -f "$2"/"$3" -t "$3" -Z aes128-gcm@openssh.com ; then
		echo -e "${INFO}	Key generation: DONE."
		echo -e "${INFO}	Setting access controls..."
		if chmod 600 "$2"/"$3" ; then
			echo -e "${INFO}	DONE."
		else
			echo -e "${ERROR}	Setting access controls failed"
		fi
	else
		echo -e "${INFO}	Failed to run ssh-keygen."
	fi
	return 0
}