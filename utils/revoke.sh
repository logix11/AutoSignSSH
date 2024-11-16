#!/bin/bash
revoke(){
	printf "\nDoes the key belnong to the host or user :: 
	
	[0] Return to menu.
	[1] Host's key.
	[2] User's key.

	Your input ::"
	local keys
	while :
	do
		read -r keys
		if [[ $keys == 0 ]]
		then
			return 0
		elif [[ $keys == 1 ]]
		then
			keys="hosts"
			break
		elif [[ $keys == 2 ]]
		then
			keys="users"
			break
		else
			printf "Invalid input. Try again :: "
		fi 
	done
	keys=("$keys"/*.pub) # List the items and store them in the variable
	printf "Select the key you want to verify.\n"
	for i in "${!keys[@]}"; do # For i in each item of the list 
		echo "	[$i] ${keys[i]}" # print the item
	done
	printf "	Your input :: "
	local key
	local choice
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
	
	if ssh-keygen -k -u -f krl.krl "$key"
	then
		echo Revoking key...DONE
	else
		echo ERROR: could not revoke key, exiting...
		exit $SSH_FAILURE
	fi
	return 0
}

