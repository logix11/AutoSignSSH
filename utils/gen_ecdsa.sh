#!/bin/bash

gen_ecdsa(){
	# Ensuring that the input is valid.
	local bit
	while :
	do
		printf "\n--------------------------------------------------------------------------------\n\n"

		echo "		Enter key's bit-length:"
		echo "			[0] Return to menu."
		echo "			[1] 256-bit long."
		echo "			[2] 384-bit long."
		echo "			[3] 521-bit long."
		echo
		read -rp "			Your input :: " bit
		if [[ $bit == 0 ]] ; then
			echo -e "${INFO}	Returning to menu..."
			return 0
		elif [[ $bit -gt 3 || $bit -lt 0 ]] ; then
			echo -e "${WARNING}	Invalid input. Try again"
		else
		
			printf "\n--------------------------------------------------------------------------------\n\n"
	
			echo -e "${INFO}	Generating the key, it'll prompt you for an encryption passphrase."
			echo -e "${INFO}	Do _NOT_ set a passphrase UNLESS the key is for the client."
			if [[ $bit == 1 ]] ; then
				bit=256
			elif [[ $bit -gt 2 ]] ; then
				bit=384
			else
				bit=521
			fi 

			if ssh-keygen -a "$1" -b "$bit" -f "$2"/id_ecdsa -t ecdsa \
				-Z aes128-gcm@openssh.com ; then
				echo -e "${SUCCESS}	Key generation: DONE."

				if [[ $2 == "hosts" ]] ; then 
					echo -e "${INFO}	Referencing host key in sshd_config"
					if sed -i "/# Host keys/a HostKey    $(pwd)/host/id_ecdsa" sshd_config
					then 
						echo -e "${SUCCESS} Key is now references"
					else 
						echo -e "${ERROR} Operation failed. Please, reference it yourself"
					fi	
				fi
				
			else
				echo -e "${ERROR}	failed to run ssh-keygen."
			fi
			break
		fi
	done
	return 0
}