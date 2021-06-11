#!/usr/bin/env bash
######################################################################################
# Title:         Cloudbox Restore Service: Restore Script                            #
# Author(s):     l3uddz, desimaniac                                                  #
# URL:           https://github.com/Cloudbox/Cloudbox                                #
# Description:   Restores encrypted config files from Cloudbox Restore Service.      #
# --                                                                                 #
#             Part of the Cloudbox project: https://cloudbox.works                   #
######################################################################################
#                     GNU General Public License v3.0                                #
######################################################################################
# Usage:                                                                             #
# ======                                                                             #
# Simple:                                                                            #
# curl -s https://cloudbox.works/scripts/restore.sh | bash -s 'USER' 'PASS'          #
# wget -qO- https://cloudbox.works/scripts/restore.sh | bash -s 'USER' 'PASS'        #
#                                                                                    #
# Custom Cloudbox Path:                                                              #
# curl -s https://cloudbox.works/scripts/restore.sh | bash -s 'USER' 'PASS' 'PATH'   #
# wget -qO- https://cloudbox.works/scripts/restore.sh | bash -s 'USER' 'PASS' 'PATH' #
######################################################################################

# vars
files=( "ansible_vault" "ansible.cfg" "accounts.yml" "settings.yml" "adv_settings.yml" "backup_config.yml" "rclone.conf")
restore="restore.cloudbox.works"
folder="$HOME/.restore_service_tmp"
green="\e[1;32m"
red="\e[1;31m"
nc="\e[0m"
done="[ ${green}DONE${nc} ]"
fail="[ ${red}FAIL${nc} ]"
ignore="[ ${red}IGNORE${nc} ]"

# Print banner

echo -e "
$green┌─────────────────────────────────────────────────────────────────────┐
$green│ Title:         Cloudbox Restore Service: Restore Script             │
$green│ Author(s):     l3uddz, desimaniac                                   │
$green│ URL:           https://github.com/cloudbox/cloudbox                 │
$green│ Description:   Restores encrypted config files from the             │
$green│                Cloudbox Restore Service.                            │
$green├─────────────────────────────────────────────────────────────────────┤
$green│         Part of the Cloudbox project: https://cloudbox.works        │
$green├─────────────────────────────────────────────────────────────────────┤
$green│                  GNU General Public License v3.0                    │
$green└─────────────────────────────────────────────────────────────────────┘
$nc"

## Functions

# validate url
# https://gist.github.com/hrwgc/7455343
function validate_url(){
  if [[ `wget -S --spider $1 2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
    return 0
  else
    return 1
  fi
}

## Main

# inputs
USER=$1
PASS=$2
DIR=${3:-/srv/git/cloudbox}

# validate inputs
if [ -z "$USER" ] || [ -z "$PASS" ]
then
      echo "You must provide the USER & PASS as arguments"
      exit 1
fi

# validate folders exist
TMP_FOLDER_RESULT=$(mkdir -p $folder)
if [ ! -z "$TMP_FOLDER_RESULT" ]
then
    echo "Failed to ensure $folder was created..."
    exit 1
else
   rm -rf $folder/*
fi


RESTORE_FOLDER_RESULT=$(mkdir -p $DIR)
if [ ! -z "$RESTORE_FOLDER_RESULT" ]
then
    echo "Failed to ensure $DIR was created..."
    exit 1
fi

# SHA1 username
USER_HASH=$(echo -n "$USER" | openssl dgst -sha1 | sed 's/^.*= //')
echo "User Hash: $USER_HASH"
echo ''

# Fetch files
echo "Fetching files from $restore..."
echo ''
for file in "${files[@]}"
do
        :
        # wget file
        if [ "$file" ==  "ansible_vault" ]; then
                printf '%-20.20s' ."$file"
        else
                printf '%-20.20s' "$file"
        fi
        URL=http://$restore/load/$USER_HASH/$file
        if validate_url $URL; then
            wget -qO $folder/$file.enc $URL
            # is the file encrypted?
            file_header=$(head -c 10 $folder/$file.enc | tr -d '\0')
            if [[ $file_header == Salted* ]]; then
                    echo -e $done
            else
                    echo -e $fail
                    exit 1
            fi
        else
          echo -e $ignore
        fi
done

echo ''

# Decrypt files
echo 'Decrypting fetched files...'
echo ''
for file in $folder/*
do
        :
        filename="$(basename -- $file .enc)"
        # wget file
        if [ "$filename" ==  "ansible_vault" ]; then
                printf '%-20.20s' ."$filename"
        else
                printf '%-20.20s' "$filename"
        fi
        DECRYPT_RESULT=$(openssl enc -aes-256-cbc -d -salt -md md5 -in $folder/${filename}.enc -out $folder/$filename -k "$PASS" >/dev/null 2>&1)
        # was the file decryption successful?
        if [ -z "$DECRYPT_RESULT" ]; then
                echo -e $done
                rm $folder/${filename}.enc
        elif [ "$filename" ==  "ansible_vault" ]; then
                echo -e $ignore
        else
                echo -e $fail
                exit 1
        fi
done

echo ''

# Move decrypted files
echo 'Moving decrypted files...'
echo ''
for file in $folder/*
do
        :
        # move file
        filename="$(basename -- $file)"
        if [ "$filename" ==  "ansible_vault" ]; then
                printf '%-20.20s' ."$filename"
                if [ -f "$folder/$filename" ]; then
                        mv $folder/$filename $HOME/.$filename 2>&1
                        echo -e $done
                else
                        echo -e $ignore
                fi
        else
                printf '%-20.20s' "$filename"
                MOVE_RESULT=$(mv $folder/$filename $DIR/$filename 2>&1)
                # was the decrypted file moved successfully?
                if [ -z "$MOVE_RESULT" ]; then
                        echo -e $done
                else
                        echo -e $fail
                        exit 1
                fi
        fi
done

echo ''

# finish
exit 0
