#!/bin/bash
SSH_REVERR=10

revoke(){
	echo "		Does the key belnong to the host or user?"
	echo
	echo "			[0] Return to menu."
	echo "			[1] Host's key."
	echo "			[2] User's key."

	local keys
	while :
	do
		read -rp "			Your input :: " keys
		if [[ $keys == 0 ]] ; then
			return 0
		elif [[ $keys == 1 ]] ; then
			keys="hosts"
			break
		elif [[ $keys == 2 ]] ; then
			keys="users"
			break
		else
			echo -e "${WARNING}	Invalid input. Try again."
		fi 
	done
		
	printf "\n--------------------------------------------------------------------------------\n\n"

	keys=("$keys"/*.pub) # List the items and store them in the variable
	echo "		Select the key you want to verify."
	for i in "${!keys[@]}"; do # For i in each item of the list 
		echo "			[$i] ${keys[i]}" # print the item
	done
	local key
	local choice
	while : ; do
		read -rp "		Your input :: " choice 
		if [[ $choice -gt ${#keys[@]} || $choice -lt 0 ]] ; then # If choice is greater than list length, or smaller than zero then.
			printf "Invalid choice. Try again :: "
		else
			key="${keys[choice]}" # Store the path to the key in this variable
			break
		fi
	done
		
	printf "\n--------------------------------------------------------------------------------\n\n"

	echo -e "${INFO}	Revoking key..."
	# Test the command, if it does not work, exit with error message.
	if ssh-keygen -k -u -f krl.krl "$key" ; then
		echo -e "${SUCCESS}	DONE"
	else
		echo -e "${ERROR}	Could not revoke key, returning..."
		return $SSH_REVERR
	fi
	return 0
}