#!/bin/bash

gen_rsa(){
	local bits
	while :
	do
		printf "\n--------------------------------------------------------------------------------\n"
		echo "Choose a key length:"
		echo "	[0] Return to menu."
		echo "	[1] 2048-bits."
		echo "	[2] 3072-bits (recommended)."
		echo "	[3] 4096-bits."

		read -rp "	Your input :: " bits
		if [[ $bits == 0 ]]
		then
			return 0
		elif [[ $bits == 1 ]]
		then
			bits=2048
			break
		elif [[ $bits == 2 ]]
		then
			bits=3072
			break
		elif [[ $bits == 3 ]]
		then
			bits=4096
			break
		else
			echo Invalid input. Try again.
		fi
	done
	
	printf "\nGenerating the key, it'll prompt you for an encryption passphrase.\n"
	if ssh-keygen -a "$1" -f "$2"/id_rsa -b "$bits" -t rsa \
	-Z aes128-gcm@openssh.com
	then
		printf "Key generation: DONE\n"
		printf "Setting access controls..."
		if chmod 600 "$2"/id_rsa
		then
			echo DONE.
		else
			echo ERROR: setting access controls failed, exiting...
			exit $PERMS_ERROR
		fi 
	else
		echo ERROR: echo failed to run ssh-keygen, exiting...
		exit $SSH_FAILURE
	fi
	return 0
}
