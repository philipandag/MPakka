#!/bin/bash
# Filip Gołaś 188776
# MPakka - a script to sort and archivize files using their extensions

SELECTED_PATH="$(pwd)"
BACKUP_FOLDER="BACKUP-"$(date -I)
BACKUP_DIR="$(pwd)"
FIND_COPIES="FALSE"
ARCHIVIZE="FALSE"
SET_CRON_JOB="FALSE"
getOptions()
{
	while getopts "rap:d:f:c:" options; do
		case "${options}" in
		p)
			SELECTED_PATH=${OPTARG}
			;;
		d)
			BACKUP_DIR=${OPTARG}
			;;
		f)
			BACKUP_FOLDER=${OPTARG}
			;;
		r)
			FIND_COPIES="TRUE"
			;;
		a)
			ARCHIVIZE="TRUE"
			;;
		c)
			SET_CRON_JOB="TRUE"
			CRON_FREQUENCY=${OPTARG}
			;;
		*)
			echo "Incorrect options"
			;;
		?)
			echo "Incorrect options"
			;;
		esac
		
	done
}

getTypes()
{
	FILES=$(ls $SELECTED_PATH | tr ' ' '\n' | grep -T ".*\..*")
	TYPES=$(echo $FILES | tr ' ' '\n' | rev | cut -d"." -f1 | rev | sort | uniq)
}

createDirs()
{
	for TYPE in $TYPES
	do
		mkdir $BACKUP_DIR/$BACKUP_FOLDER/$TYPE 2> /dev/null
	done
}

moveFiles()
{
	for FILE in $FILES
	do
		DIR=$(echo $FILE | rev | cut -d"." -f1 | rev)
		cp $SELECTED_PATH/$FILE $BACKUP_DIR/$BACKUP_FOLDER/$DIR/$FILE
	done
}

findSizes()
{
	local FILES_OF_TYPE=$1
	local SIZES=""
		for FILE in $FILES_OF_TYPE
		do
			local SIZES+=$(stat -c %s "$FILE")\ 
		done
		echo "$SIZES" | tr ' ' '\n' | sort | uniq -c | grep -v -T ".*\ 1" | rev | cut -d" " -f1 | rev
}

findCopies()
{
	for TYPE in $TYPES
	do
		local TYPE_PATH=$BACKUP_DIR/$BACKUP_FOLDER/$TYPE
		local FILES=$(ls $TYPE_PATH)
		SIZES=$(findSizes "$FILES")
		for SIZE in $SIZES
		do
			SUSPECTED_FILES=""
			for FILE in $FILES
			do
				if [[ $(stat -c %s "$FILE") -eq $SIZE ]]
				then
					SUSPECTED_FILES+="$FILE"\ 
				fi
			done
			
			SUMS=""

			for FILE in $SUSPECTED_FILES
			do
				SUMS+=$(md5sum $FILE | cut -d" " -f1)\ 
			done

			SUMS=$(echo "$SUMS" | tr ' ' '\n' | sort | uniq -c | grep -v -T ".*\ 1" | rev | cut -d" " -f1 | rev)

			for SUM in $SUMS
			do
				LEFT_ONE="FALSE"
				ORIGINAL_FILE=""
				for FILE in $SUSPECTED_FILES
				do
					if [[ $LEFT_ONE == "FALSE" ]]
					then
						ORIGINAL_FILE="$FILE"
						LEFT_ONE="TRUE"
						continue
					fi

					if [[ $(md5sum "$FILE" | cut -d" " -f1) = $SUM ]]
					then
						echo "$FILE jest kopią $ORIGINAL_FILE, usunąć? (t/n)"
						read DECYZJA
						case $DECYZJA
						in
							t)
								#rm "$FILE"
								echo "Usunięto $FILE";;
							n)
								echo "Nie usunięto $FILE";;
							*)
								echo "Nie usunięto $FILE";;
						esac
						break
					fi
				done
			done
		done
	done
}

archivize()
{
	TAR_RESULT=$(tar -czf $BACKUP_DIR/$BACKUP_FOLDER.tar.gz $BACKUP_DIR/$BACKUP_FOLDER > /dev/null 2> /dev/null)
	rm -r $BACKUP_DIR/$BACKUP_FOLDER
}

setCronJob()
{
	SCRIPT_NAME=$(basename "$0")
	SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
	NEW_CRON=$(mktemp)
	crontab -l > "$NEW_CRON" 2> /dev/null
	
	case $CRON_FREQUENCY in
		hourly)
			echo "0 * * * * $SCRIPT_DIR/$SCRIPT_NAME $@" > "$NEW_CRON"
			crontab "$NEW_CRON"
			rm "$NEW_CRON"
			echo "Cron"
		;;
		daily)
			echo "0 0 * * * $SCRIPT_DIR/$SCRIPT_NAME" > "$NEW_CRON"
			crontab "$NEW_CRON"
			rm "$NEW_CRON"
		;;
		weekly)
		echo "0 0 * * 0 $SCRIPT_DIR/$SCRIPT_NAME" > "$NEW_CRON"
			crontab "$NEW_CRON"
			rm "$NEW_CRON"
		;;
		monthly)
		echo "0 0 1 * * $SCRIPT_DIR/$SCRIPT_NAME" > "$NEW_CRON"
			crontab "$NEW_CRON"
			rm "$NEW_CRON"
		;;
		yearly)
		echo "0 0 1 1 * $SCRIPT_DIR/$SCRIPT_NAME" > "$NEW_CRON"
			crontab "$NEW_CRON"
			rm "$NEW_CRON"
		;;
		*)
		echo "Incorrect cron frequency, see man for help"
		;;
	esac

}

getOptions "$@"

mkdir $BACKUP_DIR 2> /dev/null
mkdir $BACKUP_DIR/$BACKUP_FOLDER 2> /dev/null

getTypes

createDirs

moveFiles

if [[ $FIND_COPIES == "TRUE" ]]; then
	findCopies

fi
if [[ $ARCHIVIZE == "TRUE" ]]; then
	archivize
fi

if [[ $SET_CRON_JOB == "TRUE" ]]; then
	setCronJob
fi



