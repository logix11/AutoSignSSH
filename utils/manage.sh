#!/bin/bash

# Exit codes
PATH_ERROR=2

# Importing
# shellcheck disable=SC1091
source "${ASSH_ROOT}/utils/generate.sh"
# shellcheck disable=SC1091
source "${ASSH_ROOT}/utils/sign_user.sh"
# shellcheck disable=SC1091
source "${ASSH_ROOT}/utils/sign_host.sh"
# shellcheck disable=SC1091
source "${ASSH_ROOT}/utils/verify.sh"
# shellcheck disable=SC1091
source "${ASSH_ROOT}/utils/revoke.sh"
# shellcheck disable=SC1091
source "${ASSH_ROOT}/utils/print.sh"

# Define color variables
BLUE='\033[97;44m'      # Dark Blue background, white text
RED='\033[41m'       # Red background
YELLOW='\033[48;5;214m' # Yellow background, dark text
RESET='\033[0m'      # Reset to default

INFO="${BLUE}[ INFO ]${RESET}"
# shellcheck disable=SC2034
ERROR="${RED}[ ERROR ]${RESET}"
WARNING="${YELLOW}[ WARNING ]${RESET}"

manage(){
	local condition
	echo
	echo -e "${INFO}	This script must be running in the SSH CA's home directory, i.e.,"
	echo -e "${INFO}	in the sshca/ directory that was created earlier. If this condition is"
	echo -e "${INFO}	not satisfied, then you must guide the program to find that directory."
	local path
	while : ; do
		read -rp "		Is the condition satisfied? [Y/n] " condition
		if [[ $condition == "n" || $condition == "N" ]] ; then
			while : ; do
				read -rp "		Enter the path to the directory (or leave blank to exit) :: " path
				if [[ -z $path ]] ; then
					echo -e "${WARNING}	Exiting..."
					exit $PATH_ERROR
				elif cd "$path" ; then
					echo -e "${SUCCESS}	Moved to the sshca/ directory"
					break # Exiting the most recent loop.
				else
					echo -e "${WARNING}	Invalid path. Try again."
				fi
			done
			break
		elif [[ $condition == "y" || $condition == "Y" ]] ; then
			echo -e "${INFO}	Proceeding..."
			break
		else
			echo -e "${SUCCESS}	Invalid input. Try again :: "
		fi
	done
	echo -e "${INFO}	Proceeding..."

	printf "\n--------------------------------------------------------------------------------\n"

	local choice
	while : ; do
		echo "		Choose an option."
		echo "			[0] Exit."
		echo "			[1] Generate a private key."
		echo "			[2] Sign on a user's key."
		echo "			[3] Sign on a host's key."
		echo "			[4] Verify a certificate."
		echo "			[5] Revoke a certificate."
		echo "			[6] Print out a certificate."
	
		read -rp "			Your input :: " choice
		if [[ $choice == "0" ]] ; then
			exit 0
		elif [[ $choice -gt 6 || $choice -lt 0 || -z $choice ]] ; then
			echo echo -e "${WARNING}	Invalid input. Try again."
		else
			if [[ $choice == 1 ]] ; then
				generate_key "hosts"
			elif [[ $choice == 2 ]] ; then
				sign_user
			elif [[ $choice == 3 ]] ; then
				sign_host
			elif [[ $choice == 4 ]] ; then
				verify
			elif [[ $choice == 5 ]] ; then
				revoke
			elif [[ $choice == 6 ]] ; then
				print
			else
				echo 
			fi
		fi
	done
	return 0
}
manage