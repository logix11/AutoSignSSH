#!/bin/bash

gen_ecdsa(){
	# Ensuring that the input is valid.
	local bit
	while :
	do
		printf "\n--------------------------------------------------------------------------------\n"

		echo "Enter key's bit-length:"
		echo "	[0] Return to menu."
		echo "	[1] 256-bit long."
		echo "	[2] 384-bit long."
		echo "	[3] 521-bit long."

		read -rp "\n	Your input :: " bit
		if [[ $bit == 0 ]]
		then
			echo Returning to menu...
			return 0
		elif [[ $bit -gt 3 || $bit -lt 0 ]]
		then
			printf "Invalid input. Try again"
		else
		
			printf "\n--------------------------------------------------------------------------------\n"
	
			echo "Generating the key, it'll prompt you for an encryption passphrase."
			if [[ $bit == 1 ]]
			then
				bit=256
			elif [[ $bit -gt 2 ]]
			then
				bit=384
			else
				bit=521
			fi 

			if ssh-keygen -a "$1" -b "$bit" -f "$2"/id_ecdsa -t ecdsa \
			-Z aes128-gcm@openssh.com
			then
				echo "Key generation: DONE."

				printf "\n--------------------------------------------------------------------------------\n"
	
				printf "Setting access controls..."
				if chmod 600 "$2"/id_ecdsa
				then
					echo DONE.
				else
					echo ERROR: setting access controls failed, exiting...
					exit "$PERMS_ERROR"
				fi
			else
				echo failed to run ssh-keygen, exiting...
				exit "$SSH_FAILURE"
			fi
			break
		fi
	done
	return 0
}
