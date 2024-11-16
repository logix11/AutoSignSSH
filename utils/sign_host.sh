#!/bin/bash

sign_host(){
	local keys
	keys=(hosts/*.pub) # List the items and store them in the variable
	printf "Select the key you want to sign on.\n"
	for i in "${!keys[@]}"; do # For i in each item of the list 
		echo "	[$i] ${keys[i]}" # print the item
	done

	local key
	local choice
	printf "	Your input :: "
	while : ; do
		read -r choice 
		if [[ $choice -gt ${#keys[@]} || $choice -lt 0 ]] # If choice is greater than list length, or smaller than zero then.
		then 
			printf "Invalid choice. Try again :: "
		else
			key="${keys[choice]}" # Store the path to the key in this variable
			break
		fi
	done

	local identifier
	printf "\n--------------------------------------------------------------------------------\n"
	read -rp "Specify the key identifier (it does not have to be unique, but it should be meaningful):: " identifier
	
	local principal
	printf "\n--------------------------------------------------------------------------------\n"
	echo "Specify the principal(s), it can be the FQDN or IP address(s)."
	echo "You can specify more than one in a list, separated by commas, without any spaces like so: principal1,principal2,principal3,...,principaln"
	read -rp "	Your input :: " principal
	echo "Signing on the key. It'll ask for SUDO password, because the of access controls."
	if sudo ssh-keygen -s ca/ca_host_key -I "$identifier" -V +90d -n "$principal" -h "$key" 
	then
		echo DONE.
	else 
		echo ERROR: echo failed to run ssh-keygen, exiting...
		exit "$SSH_FAILURE"
	fi
	return 0
}