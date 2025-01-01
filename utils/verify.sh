#!/bin/bash
SSH_ERROR=1
SSH_SIGERR=8
SSH_CERTERR=9

verify(){
	local keys
	local ca_path

	# Giving the user the choice between selecting the key that is designated
	# to the hosts or to the users
	echo "		Choose a CA public key to utilize"
	
	echo "			[0] Return to menu."
	echo "			[1] Host's key."
	echo "			[2] User's key."

	while : ; do
		read -rp "			Your input :: " ca_path
		if [[ $ca_path == 0 ]] ; then
			return 0
		elif [[ $ca_path == 1 ]] ; then
			ca_path="ca/ca_host_key.pub"
			keys="hosts"
			break
		elif [[ $ca_path == 2 ]] ; then
			ca_path="ca/ca_user_key.pub"
			keys="users"
			break
		else
			echo -e "${WARNING}	Invalid input. Try again."
		fi 
	done

	# Giving the user a list of host or user keys to select from it.
	# First, list the items and store them in the variable
	keys=("$keys"/*.pub) 
	echo "		Select the key you want to verify."
	for i in "${!keys[@]}" ; do # For i in each item of the list 
		echo "	[$i] ${keys[i]}" # print the item
	done
	local key
	local choice
	while : ; do
		read -rp "Your input :: " choice 
		if [[ $choice -gt ${#keys[@]} || $choice -lt 0 ]] ; then # If choice is greater than list length, or smaller than zero then.
			echo -e "${WARNING}	Invalid choice. Try again."
		else
			key="${keys[choice]}" # Store the path to the key in this variable
			break
		fi
	done

	# For this, I'll need to treat the output by leaving one line, that is, the
	# line that contains the CA's fingerprint. 

	# Then, I need to split it two times in order to extract the fingerprint 
	# alone. The first split will be based on the character ":", and will give 
	# two sections: the fingerprint and the algorithm's name. 
	
	# The second split will be based on the space between the fingerprint and 
	# the algorithm's name, and we'll take the first section --the fingerprint 
	# (finally).

	# Test if the ssh command works.
	echo "${INFO}	Extracting fingerprint from the certificate..."
	if ssh-keygen -L -f "$key" ; then
		fingerprint=$(ssh-keygen -L -f "$key" | grep "Signing CA"| cut \
		-d ':' -f 3 | cut -d ' ' -f 1)
		echo -e "${SUCCESS} DONE."
	else
		echo -e "${ERROR}	Could not extract fingerprint from the certificate, returning..."
		return $SSH_ERROR
	fi
	
	echo -e "${INFO}	Extracting fingerprint from the CA certificate..."
	if ssh-keygen -l -f "$ca_path" ; then
		ca_hash=$(ssh-keygen -l -f "$ca_path" | cut -d ' ' -f 2 | cut \
		-d ':' -f 2)
		echo -e "${SUCCESS}	DONE."
	else
		echo -e "${ERROR} Could not extract fingerprint from the CA certificate, returning..."
		return $SSH_ERROR
	fi
	
	echo -e "${INFO}	Verifying signature..."
	if [[ $fingerprint != "$ca_hash" ]] ; then
		echo -e "${WARNING}	The signature is invalid."
		return $SSH_SIGERR
	fi
	echo -e "${SUCCESS}	The signature is valid."
	
	# We'll have some splits to do. Firstly, we grep the line of validity period.
	# Second, we'll split it in a way to leave only the part of end of validiy.
	# Lastly, we'll have it like "o <date>T<time>", so we'll have  to split it
	# again to get rid of that o.
	local date
	echo -e "${INFO}	Exctracting the certificate's validity date..."
	if ssh-keygen -lf "$ca_path" ; then
		date=$(ssh-keygen -lf "$ca_path" | grep Valid | cut -d 't' -f 2 | cut \
		-d ' ' -f 2)
		echo -e "${SUCCESS}	DONE."
	else
		echo -e "${ERROR}	Could not extract the certificate\'s validity date, returning..."
		return $SSH_ERROR
	fi
	# We'll now convert it to epoch seconds
	s_date=$(date -d "$date" +%s)

	# We'll get the current epoch seconds
	epoch_seconds=$(date +%s)
	echo -e "${INFO}	Verifying validity period..."
	if [[ $s_date -gt $epoch_seconds ]] ; then
		echo -e "${WARNING}	The certificate is no longer valid."
		return $SSH_CERTERR
	fi
	echo -e "${SUCCESS}	DONE."

	# We'll now verify it against the Key Revokation List, the equivalent for
	# Certificate Revokation List in Transport Layer Security.

	if [ -a krl.krl ] && ! ssh-keygen -Q -f krl.krl "$key" ; then
		echo -e "${WARNING}	The certificate is revoked"
		return 0
	fi
	echo -e "${SUCCESS}	DONE."
	echo -e "${SUCCESS}	The certificate is valid."
	return 0
}
