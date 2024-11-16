#!/bin/bash

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
				echo "Where to store?"
				echo "	[1] Hosts folder"
				echo "	[2] Users folder"

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
