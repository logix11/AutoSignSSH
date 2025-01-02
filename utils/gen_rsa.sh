#!/bin/bash

gen_rsa(){
	local bits
	while : ; do
		printf "\n--------------------------------------------------------------------------------\n\n"
	
		echo "		Choose a key length:"
		echo "			[0] Return to menu."
		echo "			[1] 2048-bits."
		echo "			[2] 3072-bits (recommended)."
		echo "			[3] 4096-bits."
		echo 
		read -rp "		Your input :: " bits
		if [[ $bits == 0 ]] ; then
			return 0
		elif [[ $bits == 1 ]] ; then
			bits=2048
			break
		elif [[ $bits == 2 ]] ; then
			bits=3072
			break
		elif [[ $bits == 3 ]] ; then
			bits=4096
			break
		else
			echo -e "${WARNING}	Invalid input. Try again."
		fi
	done
	
	printf "\n--------------------------------------------------------------------------------\n\n"
	
		echo -e "${INFO}	Generating the key, it'll prompt you for an encryption passphrase."
		echo -e "${INFO}	Do _NOT_ set a passphrase UNLESS the key is for the client."
	if ssh-keygen -a "$1" -f "$2"/id_rsa -b "$bits" -t rsa -Z aes128-gcm@openssh.com
	then
		echo -e "${SUCCESS}	Key generation: DONE."
		if [[ $2 == "hosts" ]] ; then 
			echo -e "${INFO}	Referencing host key in sshd_config"
			if sed -i "/# Host keys/a HostKey    $(pwd)/host/id_rsa" sshd_config
			then 
				echo -e "${SUCCESS} Key is now references"
			else
				echo -e "${ERROR} Operation failed. Please, reference it yourself"
			fi	
		fi	
	else
		echo -e "${ERROR}	failed to run ssh-keygen."
	fi
	return 0
}