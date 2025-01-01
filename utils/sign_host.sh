#!/bin/bash
SSH_SIGERR=8

sign_host(){
	# This function is very similar to sign_user.sh, check it for explanation
	local keys
	keys=(hosts/*.pub) # List the items and store them in the variable
	printf "		Select the key you want to sign on.\n"
	for i in "${!keys[@]}"; do # For i in each item of the list 
		echo "			[$i] ${keys[i]}" # print the item
	done

	local key
	local choice
	while : ; do
		read -rp "			Your input :: " choice 
		# If choice is greater than list length, or smaller than zero then.
		if [[ $choice -gt ${#keys[@]} || $choice -lt 0 ]] ; then 
			printf "			Invalid choice. Try again."
		else
			key="${keys[choice]}" # Store the path to the key in this variable
			break
		fi
	done

	printf "\n--------------------------------------------------------------------------------\n\n"

	local identifier
	read -rp "			Specify the key identifier (it does not have to be unique, but it should be meaningful):: " identifier
	
	printf "\n--------------------------------------------------------------------------------\n\n"

	local principal
	echo "			Specify the principal(s), it can be the FQDN or IP address(s)."
	echo "			You can specify more than one in a list, separated by commas, without"
	echo "			any spaces like so: principal1,principal2,principal3,...,principaln"
	read -rp "			Your input :: " principal
	
	printf "\n--------------------------------------------------------------------------------\n\n"

	echo -e "${INFO}	Signing on the key."
	if ssh-keygen -s ca/ca_host_key -I "$identifier" -V +90d -n "$principal" -h "$key" 
	then
		echo -e "${SUCCESS}	DONE."
		echo -e "${INFO} Referencing the certificate in sshd_config file."

		key="${key%.pub}"
		if sed -i "/# Host keys/a HostCertificate $(pwd)/$key-cert.pub" sshd_config
		then 
			echo -e "${SUCCESS} Certificate is now references"
		else 
			echo -e "${ERROR} Operation failed. Please, reference it yourself"
		fi		
	else 
		echo -e "${SUCCESS}	Failed to run ssh-keygen, returning..."
		return $SSH_SIGERR
	fi
	return 0
}