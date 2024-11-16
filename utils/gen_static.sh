#!/bin/bash

gen_static() {
	printf "\n--------------------------------------------------------------------------------\n"

	echo "Generating the key, it'll prompt you for an encryption passphrase."
	if ssh-keygen -a "$1" -f "$2"/"$3" -t "$3" -Z aes128-gcm@openssh.com
	then
		echo "Key generation: DONE."
		printf "Setting access controls..."
		if chmod 600 "$2"/"$3"
		then
			echo DONE.
		else
			echo ERROR: setting access controls failed, exiting...
			exit "$PERMS_ERROR"
		fi
	else
		echo ERROR: failed to run ssh-keygen, exiting...
		exit "$SSH_FAILURE"
	fi
	return 0
}
