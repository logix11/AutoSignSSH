#!/bin/bash

sign_user(){
	# List the keys and allow the user to select from the list
	local keys
	keys=(users/*.pub) # List the items and store them in the variable
	printf "Select the key you want to sign on.\n"
	for i in "${!keys[@]}"; do # For i in each item of the list 
		echo "	[$i] ${keys[i]}" # print the item
	done
	local key
	local choice
	printf "\n	Your input :: "
	while : ; do
		read -r choice 
		# If choice is greater than list length, or smaller than zero then.
		if [[ $choice -gt ${#keys[@]} || $choice -lt 0 ]] 
		then 
			printf "Invalid choice. Try again :: "
		else
			key="${keys[choice]}" # Store the path to the key in this variable
			break
		fi
	done

	printf "\n--------------------------------------------------------------------------------\n"

	local identifier
	read -rp "Specify the key identifier (it does not have to be unique, but it should be meaningful):: " identifier

	printf "\n--------------------------------------------------------------------------------\n"

	local principal
	echo "Specify the principal(s), i.e., the usernames that'll utilize it."
	echo "You can specify more than one in a list, separated by commas, without any spaces like so: principal1,principal2,principal3,...,principaln"
	read -rp "	Your input :: " principal

	printf "\n--------------------------------------------------------------------------------\n"

	# Listing the list of possible extensions
	command="sudo ssh-keygen -s ca/ca_user_key -I $identifier -V +90d -n $principal"
	local extension
	echo "The list bellow shows available extensions. You can choose as many as you want. If you leave it blank, we'll proceed then. The default is to permit everything and not force any command."
	echo "	o no-port-forwarding"
	echo "	o no-port-forwarding"
	echo "	o no-pty"
	echo "	o no-user-rc"
	echo "	o no-x11-forwarding"
	echo "	o force-command=\"/path/to/command\""

	# The user can input any extention, one at a time. Each time he enters one,
	# we add to the command.
	while :
	do
		read -rp "	Choose one :: " extension
		if [[ -z "$extension" ]]
		then
			# time to break out and proceed.
			break
		else
			command+=" -O $extension"
			echo "You can enter more, or press enter to proceed."
		fi
	done

	# We finally append the key's path to the command
	command+=" $key"

	printf "\n--------------------------------------------------------------------------------\n"

	echo "Signing on the key. It'll ask for SUDO password, because the of access controls."
	if $command #&> /dev/null # Run it and send the output to null
	then
		echo DONE.
	else 
		echo ERROR: echo failed to run ssh-keygen, exiting...
		exit $SSH_FAILURE
	fi
	return 0
}