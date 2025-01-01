#!/bin/bash

gen_static() {
	printf "\n--------------------------------------------------------------------------------\n\n"

	echo -e "${INFO}	Generating the key, it'll prompt you for an encryption passphrase."
	if ssh-keygen -a "$1" -f "$2"/"$3" -t "$3" -Z aes128-gcm@openssh.com ; then
		echo -e "${SUCCESS}	Key generation: DONE."

		if [[ $2 == "hosts" ]] ; then 
				echo -e "${INFO}	Referencing host key in sshd_config"
				if sed -i "/# Host keys/a HostKey    $(pwd)/host/$3" sshd_config
				then 
					echo -e "${SUCCESS} Key is now references"
				else 
					echo -e "${ERROR} Operation failed. Please, reference it yourself"
				fi	
			fi
	else
		echo -e "${INFO}	Failed to run ssh-keygen."
	fi
	return 0
}