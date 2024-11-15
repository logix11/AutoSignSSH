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
	printf "Greate! Let's keep going.

Task: creating directories..."
	if mkdir -p sshca/{ca,hosts,users}
	then
		echo "DONE."
	else
		echo "ERROR: Could not create directories, exitting..."  
		exit $FAILED_DIR_INIT
	fi
	echo "The created directories are:
ca/		Contains the CA's public and private keys.
hosts/	Contains the hosts' certificates.
users/	Contains the users' certificates.

--------------------------------------------------------------------------------
	"

	if cd sshca/ca
	then 
		echo "Navigating to the direcotry...DONE"
	else
		echo "ERROR: Could not navigate to the created directories, exiting ..." 
		exit $FAILED_CD
	fi

	echo "Generating a new private key for the hosts, this will prompt you for 
an encryption passphrase. 

Remember the passphrase, or use a password manager.
	"

	if ssh-keygen -a 16 -b 256 -f ca_host_key -t ecdsa -Z aes128-gcm@openssh.com
	then 
		echo "Generation of the hosts' key: DONE."
	else
		echo "ERROR: Could not generate CA's host signing keys, exiting..."
		exit $SSH_FAILURE
	fi

	echo "
Setting access controls... This reuires the root password."

	if sudo chown root:root ca_host_key* && sudo chmod 600 ca_host_key
	then 
		echo "Setting access controls to the hosts' key: DONE."
	else
		echo "ERROR: Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi

	echo "
--------------------------------------------------------------------------------

Generating a new private key for the users."

	if ssh-keygen -a 16 -b 256 -f ca_user_key -t ecdsa -Z aes128-gcm@openssh.com
	then
		echo "Generation of the users' key: DONE."
	else
		echo "ERROR: Could not generate CA's user signing keys, exiting..."
		exit $SSH_FAILURE
	fi
	printf "
Setting access controls..."

	if sudo chown root:root ca_user_key* && sudo chmod 600 ca_user_key
	then
		echo "Setting access controls to the users' key: DONE."
	else
		echo "ERROR: Could not set access controls, exiting..."
		exit $PERMS_ERROR
	fi	
	printf "
--------------------------------------------------------------------------------
	
Configuring the OpenSSH server...
Enter the path to sshd_config configuration file (or leave it blank to use the 
default path) :: " 
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
	sed -i "1s/^/TrustedUserCAKeys\n/" ../sshd_config # Prepend 
		# TrustedUserCAKeys to the beginning of the first line of that file, 
		# and theeeeeeeeeeeeeeeeeeeeeeeeeeeeeen replace it.
		# I could not reduce the complexity, sorry.
	if sed -i "/TrustedUserCAKeys/c\\TrustedUserCAKeys $(pwd)/ca_user_key" ../sshd_config
	then
		echo "DONE.
Now put this file back to production directory."
	else
		echo "ERROR: could not edit on sshd_config, exiting..." 
		exit $SED_ERROR
	fi

	printf "
Configuring the OpenSSH client...
Enter the path to ssh_known_hosts file (or leave it blank to use the default 
path) :: "

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
			echo "Invalid path. Try again"
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
		printf "ERROR: could not copy sshd_config, attempting to create a local 
one..."
		if touch ../ssh_known_hosts
		then
			echo DONE
		else
			echo ERROR: Could not create ssh_known_hosts
			exit $PERMS_ERROR
		fi
	fi

	printf "
--------------------------------------------------------------------------------

Setting it to trust the CA..."

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

	echo "The setup has finished successfully, you can start signing and issuing
certificates after the host and users receive their configuration files, i.e.,
the sshd_config and ssh_known_hosts"
	return 0
}

gen_ecdsa(){
	# Ensuring that the input is valid.
	local bit
	while :
	do
		read -rp "
--------------------------------------------------------------------------------

Enter key's bit-length:
	[0] Return to menu.
	[1] 256-bit long.
	[2] 384-bit long.
	[3] 521-bit long.

	Your input :: " bit
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
				printf "Key generation: DONE
Setting access controls..."
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
	echo "
--------------------------------------------------------------------------------	

Generating the key, it'll prompt you for an encryption passphrase."
	if ssh-keygen -a "$1" -f "$2"/"$3" -t "$3" -Z aes128-gcm@openssh.com
	then
		printf "Key generation: DONE
Setting access controls..."
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
		read -rp "
	--------------------------------------------------------------------------------

Choose a key length:
	
	[0] Return to menu.
	[1] 2048-bits.
	[2] 3072-bits (recommended).
	[3] 4096-bits.

	Your input :: " bits
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
	
	echo "
	Generating the key, it'll prompt you for an encryption passphrase."
	if ssh-keygen -a "$1" -f "$2"/id_rsa -b "$bits" -t rsa -Z aes128-gcm@openssh.com
	then
		printf "Key generation: DONE
Setting access controls..."
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
		read -rp "
--------------------------------------------------------------------------------

Which cryptographic key you want to generate?
	[0] Return to menu.
	[1] ECDSA.
	[2] ECDSA-SK.
	[3] ED25519.
	[4] ED25519-SK.
	[5] RSA.
	
	Your input :: " key
		if [[ $key == "0" ]]
		then
			echo Returning to menu...
			break
		elif [[ $key -gt "5" ]] # if it is an invalid input.
		then
			echo Invalid input. Try again

		else # If it is valid, and not zero then proceed.
			local rounds
			read -rp \
"Enter number of rounds (leave blank to set the default value) :: " rounds
			if [[ -z $rounds ]] # Default value is 16
			then
				echo Setting rounds to the default value: 16... DONE.
				rounds=16
			fi

			local folder
			while :
			do
				read -rp "
--------------------------------------------------------------------------------

Where to store?

	[1] Hosts folder
	[2] Users folder

	Your input :: " folder
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
	read -rp "
--------------------------------------------------------------------------------

Specify the key identifier (it does not have to be unique, but it should be 
meaningful):: " identifier
	
	local principal
	read -rp "
--------------------------------------------------------------------------------

Specify the principal(s)

if it's for a server, then enter the FQDN or IP address(s). 

Otherwise, specify the usernames that'll utilize it. 

You can specify more than one in a list, separated by commas, without any spaces
like so: principal1,principal2,principal3,...,principaln

Your input :: " principal

	echo \
"Signing on the key. It'll ask for SUDO password, because the of access controls."
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
		read -rp "The list bellow shows available extensions. Choose one, or leave 
it blank to leave default settings (permit everything)
	o no-port-forwarding
	o no-port-forwarding
	o no-tty
	o no-user-rc
	o no-x11-forwarding
	o force-command=\"/path/to/command\"

Give the extensions in a comma separated list, without any spaces, e.g., 
no-x11-forwarding,no-pty,no-agent-forwarding

Your input :: " extensions
################################################################################
#	This does not work because each extension must have it's dependant -O flag #
################################################################################
		if sudo ssh-keygen -s ca/ca_host_key -I "$identifier" \
			-O "$extensions" -V +90d -n "$principal" "$path" #&> /dev/null
		then
			echo DONE.
		elif sudo ssh-keygen -s ca/ca_host_key -I "$identifier" \
			-V +90d -n "$principal" "$path"
		then
			echo DONE.
		else 
			echo ERROR: echo failed to run ssh-keygen, exiting...
			exit $SSH_FAILURE
		fi
	fi
	return 0
}

manage(){
	local condition
	printf \
"
This script must be running in the SSH CA's home directory, i.e., in the sshca/ 
directory that was created earlier. If this condition is not satisfied, then you
must guide the program to find that directory. Is the current directory it? 
[Y/n] "
	read -r condition
	while :
	do
		if [[ $condition == "n" || $condition == "N" ]]
		then
			printf \
"Enter the path to the directory (or leave blank to exit) :: "
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
	echo "Proceeding...

--------------------------------------------------------------------------------
"
	local choice
	while :
	do
		printf "Choose an option.
	[0] Exit.
	[1] Generate a private key.
	[2] Sign on a user's key.
	[3] Sign on a host's key.
	[4] Verify a certificate.
	[5] Revoke a certificate.
	[6] Print out a certificate.
	
	Your input :: "
		read -r choice
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

This program will help you establish a local Secure Shell (SSH) Certificate 
Authority (CA) and manage it.

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
	printf "
--------------------------------------------------------------------------------

Select an option.
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