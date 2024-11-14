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
	printf "Greate! Let's keep going

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
	while :
	do
		read -r sshd_path

		if [[ -z $sshd_path ]]
		then
			sshd_path="/etc/ssh/sshd_config"
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
	while :
	do
		read -r ssh_path

		if [[ -z $ssh_path ]]
		then
			ssh_path="/etc/ssh/ssh_known_hosts"
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
	return
}

manage(){
	printf \
"This script must be running in the SSH CA's home directory, i.e., in the sshca/ 
directory that was created earlier. If this condition is not satisfied, then you
must guide the program to find that directory. Is the current directory it? 
[Y/n]"
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
				if [[ ! -d $path ]]
				then
					printf "Invalid path. Try again :: "
				elif cd "$path"
				then
					echo "Moved to the sshca/ directory"
					break
				else
					echo Exiting...
					exit $WRONG_PATH
				fi
			done
			break
		elif [[ $condition == "y" || $condition == "Y" ]]
		then
			echo Good job.
			break
		else
			printf "Invalid input. Try again :: "
		fi
	done
	echo "Proceeding..."
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
		elif [[ $choice == "1" ]]
		then
			echo generate
		elif [[ $choice == "2" ]]
		then
			echo sign user
		elif [[ $choice == "3" ]]
		then
			echo sign host
		elif [[ $choice == "4" ]]
		then
			echo verify
		elif [[ $choice == "5" ]] 
		then
			echo revoke
		elif [[ $choice == "6" ]]
		then
			echo print
		else
			echo Invalid Input. Try again
		fi
	done
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
	echo "No OpenSSH, exiting"
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