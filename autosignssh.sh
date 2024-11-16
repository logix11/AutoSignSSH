#!/bin/bash

# Exit codes
SSH_FAILURE=1
WRONG_PATH=2
FAILED_DIR_INIT=3
FAILED_CD=4
PERMS_ERROR=5
SED_ERROR=6

init(){
	printf "The script will establish the CA in this location, proceed? [Y/n] :: "
	local choice
	# This loop is to ensure that the input is valid.
	while :
	do
		read -r choice
		if [[ $choice == "n" || $choice == "N" ]]
		then # Wrong directory
			echo "Wrong directory, exiting..."
			exit $WRONG_PATH

		elif [[ $choice != "y" && $choice != "Y" ]]
		then # Invalid input
			printf "Invalid input. Try again :: "

		else # right directory
			break
		fi
	done
	echo "Greate! Let's keep going."

		printf "Creating directories..."
	if mkdir -p sshca/{ca,hosts,users}
	then
		echo "DONE."
	else
		echo "ERROR: Could not create directories, exitting..."  
		exit $FAILED_DIR_INIT
	fi
	echo "The created directories are:"
	echo "	ca/		Contains the CA's public and private keys."
	echo "	hosts/	Contains the hosts' certificates."
	echo "	users/	Contains the users' certificates."
	printf "\n--------------------------------------------------------------------------------\n"

	if cd sshca/ca
	then 
		echo "Navigating to the direcotry...DONE."
	else
		echo "ERROR: Could not navigate to the created directories, exiting ..." 
		exit $FAILED_CD
	fi

	echo "Generating a new private key for the hosts, this will prompt you for an encryption passphrase."

	echo "Remember the passphrase, or use a password manager."

	if ssh-keygen -a 16 -b 256 -f ca_host_key -t ecdsa -Z aes128-gcm@openssh.com
	then 
		echo "Generation of the hosts' key: DONE."
	else
		echo "ERROR: Could not generate CA's host signing keys, exiting..."
		exit $SSH_FAILURE
	fi

	printf "\nSetting access controls... This reuires the root password."

	if sudo chown root:root ca_host_key* && sudo chmod 600 ca_host_key
	then 
		echo "Setting access controls to the hosts' key: DONE."
	else
		echo "ERROR: Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi

	printf "\n--------------------------------------------------------------------------------\n"

	echo "Generating a new private key for the users."

	if ssh-keygen -a 16 -b 256 -f ca_user_key -t ecdsa -Z aes128-gcm@openssh.com
	then
		echo "Generation of the users' key: DONE."
	else
		echo "ERROR: Could not generate CA's user signing keys, exiting..."
		exit $SSH_FAILURE
	fi
	printf "\nSetting access controls..."

	if sudo chown root:root ca_user_key* && sudo chmod 600 ca_user_key
	then
		echo "Setting access controls to the users' key: DONE."
	else
		echo "ERROR: Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi	
	printf "\n--------------------------------------------------------------------------------\n"
	
	printf "Configuring the OpenSSH server...\n"
	printf "Enter the path to sshd_config configuration file (or leave it blank to use the default path) :: "

	# This loop is to ensure that the input is valid
	while :
	do
		read -r sshd_path

		if [[ -z $sshd_path ]]
		then
			local sshd_path="/etc/ssh/sshd_config"
			echo "Using default path..."
			break
		elif [[ ! -e "$sshd_path" ]]
		then
			echo "Invalid path. Try again"
		else
			echo "Understood"
			break
		fi
	done

	printf "Copying sshd_config configuration file..."
	
	if cp "$sshd_path" ../sshd_config
	then
		echo DONE
	else
		echo "ERROR: could not copy sshd_config, exiting..."
		exit $WRONG_PATH
	fi

	printf "Setting it to trust the CA..."
	sed -i "1s/^/TrustedUserCAKeys\n/" ../sshd_config # Prepend TrustedUserCAKeys
		# to the beginning of the first line of that file, and theeeeeeeeeeeeeen
		# replace it.
		# I could not reduce the complexity, sorry.
	if sed -i "/TrustedUserCAKeys/c\\TrustedUserCAKeys $(pwd)/ca_user_key" ../sshd_config
	then
		printf "DONE.\n"
		printf "Now put this file back to production directory."
	else
		echo "ERROR: could not edit on sshd_config, exiting..." 
		exit $SED_ERROR
	fi

	printf "\nConfiguring the OpenSSH client...\n"
	printf "Enter the path to ssh_known_hosts file (or leave it blank to use the default path) :: "

	# This loop is to ensure that the input is a valid one.
	while :
	do
		read -r ssh_path

		if [[ -z $ssh_path ]]
		then
			local ssh_path="/etc/ssh/ssh_known_hosts"
			echo "Using default path..."
			break
		elif [[ ! -e "$ssh_path" ]]
		then
			printf "Invalid path. Try again :: "
		else
			echo "Understood"
			break
		fi
	done
	printf "Copying sshd_ssh_known_hosts file..."
	if cp "$ssh_path" ../ssh_known_hosts
	then
		echo "DONE"
	else
		printf "ERROR: could not copy sshd_config, attempting to create a local one..."
		if touch ../ssh_known_hosts
		then
			echo DONE
		else
			echo ERROR: Could not create ssh_known_hosts
			exit $PERMS_ERROR
		fi
	fi

	printf "\n--------------------------------------------------------------------------------"
	printf "Setting it to trust the CA..."

	local ca_host_key
	ca_host_key=$(<ca_host_key.pub)
	read -rp "Enter your CA's domain name (or * for any) :: " dn
	if echo "@cert-authority ($dn) ($ca_host_key)" >> ../ssh_known_hosts
	then
		echo "DONE."
	else
		echo "ERROR: could not edit on sshd_config, exiting..."
		exit $SED_ERROR
	fi

	echo "The setup has finished successfully, you can start signing and issuing certificates after the host and users receive their configuration files, i.e., the sshd_config and ssh_known_hosts"
	return 0
}

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

		read -rp "Your input :: " bit
		if [[ $bit == "0" ]]
		then
			echo Returning to menu...
			return 0
		elif [[ $bit -gt "3" ]]
		then
			printf "Invalid input. Try again"
		else
		
			echo "Generating the key, it'll prompt you for an encryption passphrase."
			if [[ $bit == "1" ]]
			then
				bit=256
			elif [[ $bit -gt "2" ]]
			then
				bit=384
			else
				bit=521
			fi 
			if ssh-keygen -a "$1" -b "$bit" -f "$2"/id_ecdsa -t ecdsa \
			-Z aes128-gcm@openssh.com
			then
				echo "Key generation: DONE."
				printf "Setting access controls..."
				if chmod 600 "$2"/id_ecdsa
				then
					echo DONE.
				else
					echo ERROR: setting access controls failed, exiting...
					exit $PERMS_ERROR
				fi
			else
				echo failed to run ssh-keygen, exiting...
				exit $SSH_FAILURE
			fi
			break
		fi
	done
	return 0
}

gen_static() {
	printf "\n--------------------------------------------------------------------------------\n"
	echo "Generating the key, it'll prompt you for an encryption passphrase."
	if ssh-keygen -a "$1" -f "$2"/"$3" -t "$3" -Z aes128-gcm@openssh.com
	then
		printf "Key generation: DONE\n"
		printf "Setting access controls..."
		if chmod 600 "$2"/"$3"
		then
			echo DONE.
		else
			echo ERROR: setting access controls failed, exiting...
			exit $PERMS_ERROR
		fi
	else
		echo ERROR: failed to run ssh-keygen, exiting...
		exit $SSH_FAILURE
	fi
	return 0
}

gen_rsa(){
	local bits
	while :
	do
		printf "\n--------------------------------------------------------------------------------\n"
		echo "Choose a key length:"
		echo "	[0] Return to menu."
		echo "	[1] 2048-bits."
		echo "	[2] 3072-bits (recommended)."
		echo "	[3] 4096-bits."

		read -rp "	Your input :: " bits
		if [[ $bits == 0 ]]
		then
			return 0
		elif [[ $bits == 1 ]]
		then
			bits=2048
			break
		elif [[ $bits == 2 ]]
		then
			bits=3072
			break
		elif [[ $bits == 3 ]]
		then
			bits=4096
			break
		else
			echo Invalid input. Try again.
		fi
	done
	
	printf "\nGenerating the key, it'll prompt you for an encryption passphrase.\n"
	if ssh-keygen -a "$1" -f "$2"/id_rsa -b "$bits" -t rsa \
	-Z aes128-gcm@openssh.com
	then
		printf "Key generation: DONE\n"
		printf "Setting access controls..."
		if chmod 600 "$2"/id_rsa
		then
			echo DONE.
		else
			echo ERROR: setting access controls failed, exiting...
			exit $PERMS_ERROR
		fi 
	else
		echo ERROR: echo failed to run ssh-keygen, exiting...
		exit $SSH_FAILURE
	fi
	return 0
}

generate_key(){
	local key
	while :
	do
		printf "\n--------------------------------------------------------------------------------\n"
		echo "Which cryptographic key you want to generate?"
		echo "	[0] Return to menu."
		echo "	[1] ECDSA."
		echo "	[2] ECDSA-SK."
		echo "	[3] ED25519."
		echo "	[4] ED25519-SK."
		echo "	[5] RSA."
	
		read -rp "	Your input :: " key
		if [[ $key == "0" ]]
		then
			echo Returning to menu...
			break
		elif [[ $key -gt "5" ]] # if it is an invalid input.
		then
			echo Invalid input. Try again

		else # If it is valid, and not zero then proceed.
			local rounds
			read -rp "Enter number of rounds (leave blank to set the default value) :: " rounds
			if [[ -z $rounds ]] # Default value is 16
			then
				echo Setting rounds to the default value: 16... DONE.
				rounds=16
			fi

			local folder
			while :
			do
				printf "\n--------------------------------------------------------------------------------\n"
				printf "Where to store?"
				printf "	[1] Hosts folder"
				printf "	[2] Users folder"

				read -rp "	Your input :: " folder
				if [[ $folder == 1 ]]
				then
					folder="hosts"
					break
				elif [[ $folder == 2 ]]
				then
					folder="users"
					break
				else
					echo Invalid input. Try again
				fi
			done
			if [[ $key == "1" ]] # ECDSA Has predefined key bit lengths
			then
				gen_ecdsa "$rounds" "$folder" 
			elif [[ $key == "2" ]]
			then
				gen_static "$rounds" "$folder" "ecdsa-sk"
			elif [[ $key == "3" ]]
			then
				gen_static "$rounds" "$folder" "ed25519"
			elif [[ $key == "4" ]]
			then
				gen_static "$rounds" "$folder" "ed25519-sk"
			else
				gen_rsa "$rounds" "$folder"
			fi
		fi
	done
	return 0
}

sign_cert(){
	local host=$1

	local path
	tree
	printf "Enter the path to the private key :: "
	while :
	do
		read -r path
		if [[ ! -e "$path" ]]
		then
			echo "Invalid path. Try again"
		else
			echo "Understood"
			break
		fi
	done

	local identifier
	printf "\n--------------------------------------------------------------------------------\n"
	reaed -rp "Specify the key identifier (it does not have to be unique, but it should be meaningful):: " identifier
	
	local principal
	printf "\n--------------------------------------------------------------------------------\n"
	echo "Specify the principal(s)"
	echo "If it's for a server, then enter the FQDN or IP address(s)."
	echo "Otherwise, specify the usernames that'll utilize it."
	echo "You can specify more than one in a list, separated by commas, without any spaces like so: principal1,principal2,principal3,...,principaln"
	read -rp "Your input :: " principal
	echo "Signing on the key. It'll ask for SUDO password, because the of access controls."
	if $host
	then
		if sudo ssh-keygen -s ca/ca_host_key -I "$identifier" -V +90d -n "$principal" -h "$path" 
		then
			echo DONE.
		else 
			echo ERROR: echo failed to run ssh-keygen, exiting...
			exit $SSH_FAILURE
		fi
	else
		command=$(sudo ssh-keygen -s ca/ca_user_key -I "$identifier" -V +90d \
			-n "$principal")
		local extension
		echo "The list bellow shows available extensions. You can choose as many as you want. If you leave it blank, we'll proceed then. The default is to permit everything and not force any command."
		echo "	o no-port-forwarding."
		echo "	o no-port-forwarding."
		echo "	o no-tty."
		echo "	o no-user-rc."
		echo "	o no-x11-forwarding."
		echo "	o force-command=\"/path/to/command\"."

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
		command+=" $path"
		if $command #&> /dev/null
		then
			echo DONE.
		else 
			echo ERROR: echo failed to run ssh-keygen, exiting...
			exit $SSH_FAILURE
		fi
	fi
	return 0
}

verify(){
	local cert_path
	local ca_path
	printf "\nEnter the CA's public key's path :: "
	while :
	do
		read -r ca_path
		if [[ -e $ca_path ]]
		then
			break
		else
			printf "Invalid input. Try again :: "
		fi 
	done
	printf "\nEnter the certificates's path :: "
	while :
	do
		read -r cert_path
		if [[ -e $cert_path ]]
		then
			break
		else
			printf "Invalid input. Try again :: "
		fi 
	done

	# For this, I'll need to treat the output by leaving one line, that is, the
	# line that contains the CA's fingerprint. Then, I need to split it two times
	# in order to extract the fingerprint alone. The first split will be based 
	# on the character ":", and will give two sections: the fingerprint and the
	# algorithm's name. The second split will be based on the space between the 
	# fingerprint and the algorithm's name, and we'll take the first section
	# --the fingerprint (finally).
	fingerprint=$(ssh-keygen -L -f "$cert_path" | grep "Signing CA"| cut \
		-d ':' -f 3 | cut -d ' ' -f 1)
	ca_hash=$(ssh-keygen -l -f ca/ca_host_key.pub  | cut -d ' ' -f 2 | cut \
		-d ':' -f 2)
	printf "Verifying signature..."
	if [[ $fingerprint != "$ca_hash" ]]
	then
		printf "\nWARNING: the signature is invalid."
		return 1
	fi
	printf "Sucess!\nThe signature is valid.\n"
	
	# We'll have some splits to do. Firstly, we grep the line of validity period.
	# Second, we'll split it in a way to leave only the part of end of validiy.
	# Lastly, we'll have it like "o <date>T<time>", so we'll have  to split it
	# again to get rid of that o.
	local date
	date=$(ssh-keygen -Lf "$ca_path" | grep Valid | cut -d 't' -f 2 | cut \
		-d ' ' -f 2)
	
	# We'll now convert it to epoch seconds
	s_date=$(date -d "$date" +%s)

	# We'll get the current epoch seconds
	epoch_seconds=$(date +%s)
	printf "Verifying validity period..."
	if [[ $s_date -gt $epoch_seconds ]]
	then
		printf "\nWARNING: the certificate is no longer valid."
		return 1
	fi
	echo "DONE."

	# We'll now verify it against the Key Revokation List, the equivalent for
	# Certificate Revokation List in Transport Layer Security.
	printf "\nEnter the KRL's path :: "
	while :
	do
		read -r krl_path
		if [[ -e $krl_path ]]
		then
			break
		else
			printf "Invalid input. Try again :: "
		fi 
	done

	if ! ssh-keygen -Q -f "$krl_path" "$cert_path"
	then
		printf "\nWARNING: the certificate is revoked"
		return 0
	fi
	echo DONE.
	echo The certificate is valid.
	return 0
}

manage(){
	local condition
	printf "\nThis script must be running in the SSH CA's home directory, i.e., in the sshca/ directory that was created earlier. If this condition is not satisfied, then you must guide the program to find that directory. Is the current directory it? [Y/n] "
	while :
	do
		read -r condition
		if [[ $condition == "n" || $condition == "N" ]]
		then
			printf "Enter the path to the directory (or leave blank to exit) :: "
			while :
			do
				read -r path
				if [[ -z $path ]]
				then
					echo Exiting...
					exit $WRONG_PATH
				elif cd "$path"
				then
					echo "Moved to the sshca/ directory"
					break
				else
					printf "Invalid path. Try again :: "
				fi
			done
			break
		elif [[ -z $condition ]]
		then
			echo Exiting...
			exit $WRONG_PATH
		elif [[ $condition == "y" || $condition == "Y" ]]
		then
			echo Good job.
			break
		else
			printf "Invalid input. Try again :: "
		fi
	done
	echo "Proceeding..."
	echo "--------------------------------------------------------------------------------"

	local choice
	while :
	do
		echo "Choose an option."
		echo "	[0] Exit."
		echo "	[1] Generate a private key."
		echo "	[2] Sign on a user's key."
		echo "	[3] Sign on a host's key."
		echo "	[4] Verify a certificate."
		echo "	[5] Revoke a certificate."
		echo "	[6] Print out a certificate."
	
		read -rp "	Your input :: " choice
		if [[ $choice == "0" ]]
		then
			exit 0
		elif [[ $choice -gt 6 ]]
		then
			echo Invalid input. Try again
		else
			if [[ $choice == 1 ]]
			then
				generate_key "hosts"
			elif [[ $choice == 2 ]]
			then
				sign_cert false
			elif [[ $choice == 3 ]]
			then
				sign_cert true

			else
				echo 
			fi
		fi
	done
	return 0
}

# main() {

echo "
   _____          __          _________.__                _________ _________ ___ ___  
  /  _  \  __ ___/  |_  ____ /   _____/|__| ____   ____  /   _____//   _____//   |   \\
 /  /_\  \|  |  \   __\\/  _ \\______  \ |  |/ ___\ /    \ \\_____  \ \\_____  \\/    ~    \\
/    |    \  |  /|  | (  <_> )        \|  / /_/  >   |  \/        \/        \    Y    /
\____|__  /____/ |__|  \____/_______  /|__\___  /|___|  /_______  /_______  /\___|_  / 
        \/                          \/   /_____/      \/        \/        \/       \/  

-------------------------------Hello and welcome!-------------------------------

This program will help you establish a local Secure Shell (SSH) Certificate Authority (CA) and manage it.

Ensure that OpenSSH is installed before running this script.
"

if ! command -v ssh &> /dev/null
then
	echo "No OpenSSH, exiting..."
	exit $SSH_FAILURE
fi

echo "It is indeed installed."

while :
do
	printf "--------------------------------------------------------------------------------"
	printf " Select an option.
	[0] Exit.
	[1] Establish a CA.
	[2] Manage a CA
	
	Your input :: "
	read -r choice
	if [[ $choice == "0" ]]
	then
		echo Exiting...
		exit 0
	elif [[ $choice == "1" ]]
	then
		init
	elif [[ $choice == "2" ]]
	then
		manage
	else
		echo Invalid input. Try again.		
	fi
done