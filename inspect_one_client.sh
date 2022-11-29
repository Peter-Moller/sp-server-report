#!/bin/bash
# Get detailed info for a single client using the activity log
# 2022-09-06 / PM
# Department of Computer Science, Lund University

# Currently, it digs through machines that are manually specified in lists in the script. 
# The plan is to instead have the user provide either POLICYDOMAIN och a SCHEDULE and then
# get the client list from those and produce result accoringly.

client=$1
if [ -z "$client" ]; then
    echo "No client slected. Exiting..."
    exit 1
fi
ClientFile="/tmp/${client}.out"

RANGE=$2
if [ -z "$RANGE" ]; then
    DaysBack=" begintime=00:00:00"
    DaysBackRelative="day"
else
    DaysBack="-$RANGE"
    DaysBackRelative="$RANGE days"
fi

export LC_NUMERIC=en_US
NL=$'\n'
Reset="\e[0m"
ESC="\e["
ItalicFace="3"
BoldFace="1"
UnderlineFace="4"
InvertColor="7"

Client_W="%-13s"
BackedupNumfiles_H="%11s"
BackedupNumfiles_W="%'11d"
TransferredVolume_W="%13s"
BackeupElapsedtime_W="%-10s"
BackupDate_W="%-12s"
BackupTime_W="%-10s"
BackupStatus_W="%-15s"
ClientTotalSpaceUseMB_WH="%10s"
ClientTotalSpaceUsedMB_W="%'10d"
ClientTotalNumFile_WH="%11s"
ClientTotalNumFiles_W="%'11d"
ClientNumFilespaces_WH="%6s"
ClientNumFilespaces_W="%'6d"
ClientVersion_W="%-9s"
ClientLastNetWork_W="%-18s"
ClientOS_W="%-23s"
ErrorMsg_W="%-60s"

FormatStringHeader="${Client_W}${BackedupNumfiles_H}${TransferredVolume_W}  ${BackeupElapsedtime_W}${BackupDate_W}${BackupTime_W}${BackupStatus_W}${ClientNumFilespaces_WH}  ${ClientTotalNumFile_WH}  ${ClientTotalSpaceUseMB_WH}  ${ClientVersion_W}${ClientLastNetWork_W}${ClientOS_W}${ErrorMsg_W}"
FormatStringConten="${Client_W}${BackedupNumfiles_W}${TransferredVolume_W}  ${BackeupElapsedtime_W}${BackupDate_W}${BackupTime_W}${BackupStatus_W}${ClientNumFilespaces_W}  ${ClientTotalNumFiles_W}  ${ClientTotalSpaceUsedMB_W}  ${ClientVersion_W}${ClientLastNetWork_W}${ClientOS_W}${ErrorMsg_W}"
FormatStringVertical="${ESC}${ItalicFace}m%22s${Reset}%-40s\n"
FormatStringVerticalNumeric="${ESC}${ItalicFace}m%22s${Reset}%'10d\n"


#   _____   _____    ___   ______   _____       _____  ______      ______   _   _   _   _   _____   _____   _____   _____   _   _   _____ 
#  /  ___| |_   _|  / _ \  | ___ \ |_   _|     |  _  | |  ___|     |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  \ `--.    | |   / /_\ \ | |_/ /   | |       | | | | | |_        | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--. 
#   `--. \   | |   |  _  | |    /    | |       | | | | |  _|       |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  /\__/ /   | |   | | | | | |\ \    | |       \ \_/ / | |         | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/    \_/   \_| |_/ \_| \_|   \_/        \___/  \_|         \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/ 
#  


ScriptNameLocation() {
    # Find where the script resides
    # Get the DirName and ScriptName
    if [ -L "${BASH_SOURCE[0]}" ]; then
        # Get the *real* directory of the script
        ScriptDirName="$(dirname "$(readlink "${BASH_SOURCE[0]}")")"   # ScriptDirName='/usr/local/bin'
        # Get the *real* name of the script
        ScriptName="$(basename "$(readlink "${BASH_SOURCE[0]}")")"     # ScriptName='moodle_backup.sh'
    else
        ScriptDirName="$(dirname "${BASH_SOURCE[0]}")"
        # What is the name of the script?
        ScriptName="$(basename "${BASH_SOURCE[0]}")"
    fi
    ScriptFullName="${ScriptDirName}/${ScriptName}"
}

print_header() {
    printf "${ESC}${InvertColor}mBackup-report for client \"$client\" on $(date +%F" "%T)$Reset\n\n"
}

check_node_exists() {
    printf "..... making sure the client exists (1/5) ....."
    ClientInfo="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query node $client f=d")"
    ClientES=$?
    ServerName="$(echo "$ClientInfo" | grep -E "^Session established with server" | cut -d: -f1 | awk '{print $NF}')"
    #if [ $(echo "$ServerResponse" | grep -E "^ANS8002I" | awk '{print $NF}' | cut -d. -f1) -ne 0 ]; then
    if [ $ClientES -eq 11 ]; then
        printf "${ESC}48D"
        echo "Client \"$client\" does not exist on server \"$ServerName\". Exiting..."
        exit 1
    else
        ContactName="$(echo "$ClientInfo" | grep -E "^\s*Contact:" | cut -d: -f2 | sed 's/^ *//')"                                                                                    # Ex: ContactName='Peter M?ller'
        ContactEmail="$(echo "$ClientInfo" | grep -E "^\s*Email Address:" | cut -d: -f2 | sed 's/^ *//')"                                                                             # Ex: ContactEmail='peter.moller@cs.lth.se'
        NodeRegisteredDate="$(echo "$ClientInfo" | grep -E "^\s*Registration Date/Time:" | cut -d: -f2- | sed 's/^ *//' | awk '{print $1}')"                                          # Ex: NodeRegistered=2022-07-01
        if [ "$(echo "$NodeRegisteredDate" | cut -c3,6)" = "//" ]; then
            NodeRegisteredDate="20${NodeRegisteredDate:6:2}-${NodeRegisteredDate:0:2}-${NodeRegisteredDate:3:2}"
        fi
        NodeRegisteredBy="$(echo "$ClientInfo" | grep -E "^\s*Registering Administrator:" | cut -d: -f2- | sed 's/^ *//' | awk '{print $1}')"                                         # Ex: NodeRegisteredBy=ADMIN
        PolicyDomain="$(echo "$ClientInfo" | grep -E "^\s*Policy Domain Name:" | cut -d: -f2 | sed 's/^ *//')"                                                                        # Ex: PolicyDomain=PD_01
        CloptSet="$(echo "$ClientInfo" | grep -E "^\s*Optionset:" | cut -d: -f2 | sed 's/^ *//')"                                                                                     # Ex: CloptSet=PD_01_OS_MACOS_2
        Schedule="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query schedule $PolicyDomain node=$client" 2>/dev/null | grep -Ei "^\s*Schedule Name:" | cut -d: -f2 | sed 's/^ //')"       # Ex: Schedule=DAILY_10
        ScheduleStart="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query schedule $PolicyDomain $Schedule f=d" | grep -E "^\s*Start Date/Time:" | awk '{print $NF}')"         # Ex: ScheduleStart=08:00:00
        ScheduleDuration="+ $(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query schedule $PolicyDomain $Schedule f=d" | grep -E "^\s*Duration:" | cut -d: -f2 | sed 's/^ *//')" # Ex: ScheduleDuration='+ 10 Hour(s)'
        # Store the data in ClientFile:
        echo "$ClientInfo" > $ClientFile
        echo "" >> $ClientFile
    fi
    printf "${ESC}48D"
}

client_info() {
    printf "..... gathering client info (2/5) ....."
    ClientVersion="$(echo "$ClientInfo" | grep -E "^\s*Client Version:" | cut -d: -f2 | sed -e 's/ Version //' -e 's/, release /./' -e 's/, level /./' | cut -d. -f1-3)"   # Ex: ClientVersion='8.1.13'
    ClientLastNetworkTemp="$(echo "$ClientInfo" | grep -Ei "^\s*TCP/IP Address:" | cut -d: -f2 | sed -e 's/^ //')"                                                         # Ex: ClientLastNetworkTemp='10.7.58.184'
    case "$(echo "$ClientLastNetworkTemp" | cut -d\. -f1-2)" in
        "130.235") ClientLastNetwork="LU" ;;
        "10.4")    ClientLastNetwork="Static VPN" ;;
        "10.7")    ClientLastNetwork="eduroam (staff)" ;;
        "10.8")    ClientLastNetwork="eduroam (stud.)" ;;
        "10.9")    ClientLastNetwork="eduroam (other)" ;;
        "" )       ClientLastNetwork="Unknown" ;;
        * )        ClientLastNetwork="outside LU" ;;
    esac
    case "$(echo "$ClientLastNetworkTemp" | cut -d\. -f1-3)" in
        "130.235.16" ) ClientLastNetwork="CS server net" ;;
        "130.235.17" ) ClientLastNetwork="CS server net" ;;
        "10.0.16"    ) ClientLastNetwork="CS client net" ;;
    esac
    TransportMethod="$(echo "$ClientInfo" | grep -E "^\s*Transport Method:" | cut -d: -f2 | sed 's/^ *//')"
    ClientOS="$(echo "$ClientInfo" | grep -Ei "^\s*Client OS Name:" | cut -d: -f3 | sed -e 's/Microsoft //' -e 's/ release//' | cut -d\( -f1)"
    # Ex: ClientOS='Macintosh' / 'Ubuntu 20.04.4 LTS' / 'Windows 10 Education' / 'Fedora release 36' / 'Debian GNU/Linux 10' / 'CentOS Linux 7.9.2009'
    ClientOccupancy="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query occupancy $client")"
    # Get the file space IDs:
    FSIDs="$(echo "$ClientOccupancy" | grep -E "^\s*FSID:" | cut -d: -f2 | tr '\n' ' ')"                                                       # Ex: FSIDs=' 2  1 '
    # Deal with clients who are using deduplication.
    # (If they are, the server does only present the 'Logical Space Occupied' number since it actually cannot determine the physical space occupied)
    if [ -z "$(echo "$ClientOccupancy" | grep "Physical Space Occupied" | cut -d: -f2 | grep -o '-')" ]; then
        OccupiedPhrase="Physical Space Occupied"
    else
        OccupiedPhrase="Logical Space Occupied"
    fi
    ClientLastAccess="$(echo "$ClientInfo" | grep -Ei "^\s*Last Access Date/Time:" | cut -d: -f2- | sed 's/\ *//')"                            # Ex: ClientLastAccess='2018-11-01 11:39:06'
    if [ "$(echo "$ClientLastAccess" | cut -c3,6)" = '//' ]; then
        ClientLastAccessDate="20${ClientLastAccess:6:2}-${ClientLastAccess:0:2}-${ClientLastAccess:3:2}"
    else
        ClientLastAccessDate="${ClientLastAccess:0:10}"
    fi
    ClientLastAccessTime="$(echo "$ClientLastAccess" | awk '{print $NF}')"
    ClientLastAccess="$ClientLastAccessDate $ClientLastAccessTime"
    ClientTotalSpaceTemp="$(echo "$ClientOccupancy" | grep "$OccupiedPhrase" | cut -d: -f2 | sed 's/,//g' | tr '\n' '+' | sed 's/+$//')"       # Ex: ClientTotalSpaceTemp=' 217155.02+ 5.20+ 1285542.38'
    ClientTotalSpaceUsedMB=$(echo "scale=0; $ClientTotalSpaceTemp" | bc | cut -d. -f1)                                                         # Ex: ClientTotalSpaceUsedMB=1502702
    ClientTotalNumfilesTemp="$(echo "$ClientOccupancy" | grep "Number of Files" | cut -d: -f2 | sed 's/,//g' | tr '\n' '+' | sed 's/+$//')"    # ClientTotalNumfilesTemp=' 1194850+ 8+ 2442899'
    ClientTotalNumFiles=$(echo "scale=0; $ClientTotalNumfilesTemp" | bc | cut -d. -f1)                                                         # Ex: ClientTotalNumFiles=1502702
    ClientFilespaces="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query filespace $client f=d")"
    ClientNumFilespacesOnServer=$(echo "$ClientOccupancy" | grep -cE "^\s*Filespace Name:")                                                    # Ex: ClientNumFilespacesOnServer=8
    ClientFileSpacesNames="$(echo "$ClientFilespaces" | grep -E "^\s*Filespace Name:" | cut -d: -f2 | tr '\n' ',')"                            # Ex: ClientFileSpacesNames=' /, /data, /home, /boot,'
    # Add the occupancy data to the ClientFile:
    echo "$ClientOccupancy" >> $ClientFile
    # Add filespace information to the ClientFile
    echo "" >> $ClientFile
    echo "$ClientFilespaces" >> $ClientFile
    echo "" >> $ClientFile
    printf "${ESC}40D"
}

# Get the activity log for today (saves time to do it only one)
# Do not include ANR2017I ('Administrator ADMIN issued command...')
get_backup_data() {
    printf "..... gathering backup data (3/5) ....."
    echo "Below are all entries in the TSM 'actlog' regarding \"$client\" (except ANR2017I - 'Administrator ADMIN issued command...') during the given time interval:" >> $ClientFile
    dsmadmc -id=$ID -password=$PASSWORD -TABdelimited "query actlog begindate=today$DaysBack enddate=today endtime=now" | grep -Ei "\s$client[ \)]" | grep -v "ANR2017I" >> $ClientFile
    printf "${ESC}40D"
}

backup_result() {
    # Number of files:
    # (note that some client use a unicode 'non breaking space', e280af, as thousands separator. This must be dealt with!)
    # (also, note that some machines will have more than one line of reporting. We only consider the last one)
    # Sample lines:
    # 2022-09-16 12:34:01     ANE4954I (Session: 101638, Node: XXXXXX)  Total number of objects backed up:        7,002  (SESSION: 101638)
    # 2022-09-16 12:34:01     ANE4961I (Session: 101638, Node: XXXXXX)  Total number of bytes transferred:       446.50 MB  (SESSION: 101638)
    # 2022-09-15 16:24:49     ANE4964I (Session: 99285, Node: XXXXXX)  Elapsed processing time:               01:43:52  (SESSION: 99285)
    # 2022-09-15 16:24:49     ANR2579E Schedule DAILY_10 in domain PD_10 for node XXXXXX failed (return code 12). (SESSION: 99285)
    # 2022-09-16 12:34:01     ANR2579E Schedule DAILY_10 in domain PD_10 for node XXXXXX failed (return code 12). (SESSION: 101638)
    printf "..... getting backup results (4/5) ....."
    BackedupNumfiles="$(grep ANE4954I $ClientFile | sed -e 's/\xe2\x80\xaf/,/' | grep -Eo "Total number of objects backed up:\s*[0-9,]*" | awk '{print $NF}' | sed -e 's/,//g' | tail -1)"  # Ex: BackedupNumfiles='3483'
    TransferredVolume="$(grep ANE4961I $ClientFile | grep -Eo "Total number of bytes transferred:\s*[0-9,.]*\s[KMG]?B" | tail -1 | cut -d: -f2 | sed 's/\ *//' | tail -1)"                  # Ex: TransferredVolume='1,010.32 MB'
    BackeupElapsedtime="$(grep ANE4964I $ClientFile | grep -Eo "Elapsed processing time:\s*[0-9:]*" | tail -1 | awk '{print $NF}' | tail -1)"                                               # Ex: BackeupElapsedtime='00:46:10'
    LastFinishDateTemp="$(grep -E "ANR2507I|ANR2579E" $ClientFile | tail -1 | awk '{print $1}')"                                                                                            # Ex: LastFinishDateTemp=2022-09-16
    if [ "$(echo "$LastFinishDateTemp" | cut -c3,6)" = "//" ]; then
        LastFinishDate="20${LastFinishDateTemp:6:2}-${LastFinishDateTemp:0:2}-${LastFinishDateTemp:3:2}"
        else
        LastFinishDate="$LastFinishDateTemp"
    fi
    LastFinishTime="$(grep -E "ANR2507I|ANR2579E" $ClientFile | tail -1 | awk '{print $2}')"                                                                                                # Ex: LastFinishTime=12:34:01
    # Dual Execution?
    if [ -n "$(grep ANE4961I $ClientFile | awk '{print $1" "$3}' | uniq -d)" ]; then
        ErrorMsg="Dual executions (plz investigate); "
    else
        ErrorMsg=""
    fi

    # So, did it end successfully?
    if [ -n "$(grep ANR2507I $ClientFile | grep "completed successfully" | tail -1)" ]; then
        BackupStatus="Successful"
    else
        BackupStatus="ERROR"
    fi
    printf "${ESC}41D"
}

error_detection() {
    printf "..... looking for errors (5/5) ....."
    if [ -n "$(grep ANE4007E "$ClientFile")" ]; then
        ErrorMsg+="ANE4007E (access denied to object); "
    fi
    if [ -n "$(grep ANR2579E "$ClientFile")" ]; then
        ErrorCodes="$(grep ANR2579E "$ClientFile" | grep -Eio "\(return code -?[0-9]*\)" | sed -e 's/(//' -e 's/)//' | sort -u | tr '\n' ',' | sed -e 's/,c/, c/g' -e 's/,$//')"
        ErrorMsg+="ANR2579E ($ErrorCodes); "
    fi
    if [ -n "$(grep ANR0424W "$ClientFile")" ]; then
        ErrorMsg+="ANR0424W (invalid password submitted); "
    fi
    if [ -n "$(grep ANS4042E "$ClientFile")" ]; then
        ErrorMsg+="ANS4042E - object contains unrecognized characters during scheduled backups"
    fi
    printf "${ESC}37D"
}


# Print client info
print_client_info()
{
    printf "${ESC}${BoldFace}mInformation about the node:${Reset}             \n"
    printf "$FormatStringVertical" "Contact:" " $ContactName"
    printf "$FormatStringVertical" "Email address:" " $ContactEmail"
    printf "$FormatStringVertical" "Node registered by:" " ${NodeRegisteredBy:--unknown-} on ${NodeRegisteredDate:--unknown-}"
    printf "$FormatStringVertical" "Policy Domain:" " ${PolicyDomain:--unknown-}"
    printf "$FormatStringVertical" "Cloptset:" " ${CloptSet:--unknown-}"
    printf "$FormatStringVertical" "Schedule:" " ${Schedule:--unknown-} ($ScheduleStart ${ScheduleDuration,,})"
    printf "$FormatStringVertical" "Transport Method:" " ${TransportMethod:-unknown}"
    printf "$FormatStringVertical" "Connected to Server:" " ${ServerName:--}"
    printf "$FormatStringVertical" "Client version:" " $ClientVersion"
    printf "$FormatStringVertical" "Client OS:" " $ClientOS"
    printf "$FormatStringVertical" "Client last access:" " ${ClientLastAccess:-no info}"
    printf "$FormatStringVertical" "Client last network:" " ${ClientLastNetwork:-no info}"
    echo
}

# Print the result
print_result() {
    # Fix the strange situation where a backup has taken place but Return code 12 says it hasn't
    if [ "$BackupStatus" = "ERROR" ] && [ -n "$BackedupNumfiles" ] && [ -n "$TransferredVolume" ] && [ -n "$BackeupElapsedtime" ]; then
        BackupStatus="Conflicted!!"
    fi
    # Get time period in a more human form
    if [ "$DaysBack" = " begintime=00:00:00" ]; then
        #printf "${ESC}${InvertColor}mBackup-report for client \"$client\" on $(date +%F" "%T). Period: today${Reset}\n"
        PeriodString="today"
    else
        PeriodString="last ${DaysBack/-/} day$([[ ${DaysBack/-/} -gt 1 ]] && echo "s")"
    fi

    # Print information about the backup the specified time period:
    printf "${ESC}${BoldFace}mInformation about backup $PeriodString:${Reset}         \n"
    printf "$FormatStringVertical" "Backup Status:" " ${BackupStatus/ERROR/NO BACKUP FOUND}"
    printf "$FormatStringVerticalNumeric" "Nbr. files:" " ${BackedupNumfiles:-0}"
    printf "$FormatStringVertical" "Bytes transferred:" " $TransferredVolume"
    printf "$FormatStringVertical" "Time elapsed:" " $BackeupElapsedtime"
    printf "$FormatStringVertical" "Backup date:" " $LastFinishDate"
    printf "$FormatStringVertical" "Backup time:" " $LastFinishTime"
    printf "$FormatStringVertical" "Errors encountered:" " ${ErrorMsg%; }"
    echo

    # Print info about the client on the server
    printf "${ESC}${BoldFace}mClient usage of server resources:${Reset}\n"
    FormatStrOccup="%-20s%4d%-10s%'13d%'17d       %-10s%'10d"
    printf "${ESC}${UnderlineFace}mFilespace Name      FSID   Type       Nbr files   Space Occupied [MB]  Last backup  (Days ago)${Reset}\n"
    for fsid in $FSIDs
    do
        FSName=""
        NbrFiles=0
        SpaceOccup=0
        OccupInfo="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query occupancy $client $fsid nametype=fsid")"
        FSInfo="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query filespace $client $fsid nametype=fsid f=d")"
        FSName="$(echo "$OccupInfo" | grep -E "^\s*Filespace Name:" | cut -d: -f2 | sed 's/^\ //')"
        FSType="$(echo "$FSInfo" | grep -E "^\s*Filespace Type:" | cut -d: -f2 | sed 's/^\ //')"                                                # Ex: FSType=EXT4
        NbrFiles="$(echo "$OccupInfo" | grep -E "^\s*Number of Files:" | cut -d: -f2 | sed 's/^\ //' | sed 's/,//g' | cut -d\. -f1)"
        SpaceOccup="$(echo "$OccupInfo" | grep -E "Space Occupied" | cut -d: -f2 | grep -v "-" | tail -1 | sed 's/\ //' | sed 's/,//g' | cut -d\. -f1)"
        LastBackupDate="$(echo "$FSInfo" | grep -E "Last Backup Completion Date/Time:" | cut -d: -f2 | awk '{print $1}')"      # Ex: LastBackupDate=11/28/22
        if [ "$(echo "$LastBackupDate" | cut -c3,6)" = "//" ]; then
            LastBackupDate="20${LastBackupDate:6:2}-${LastBackupDate:0:2}-${LastBackupDate:3:2}"
        fi
        LastBackupNumDays="$(echo "$FSInfo" | grep -E "Days Since Last Backup Completed:" | cut -d: -f2 | awk '{print $1}' | sed 's/[,<]//g')"   # Ex: LastBackupNumDays='<1'
        printf "$FormatStrOccup\n" "${FSName:-no name}" "$fsid" "   ${FSType:--??-}" "${NbrFiles:-0}" "${SpaceOccup:-0}" "${LastBackupDate}" "${LastBackupNumDays:-0}"
    done
    if [ -n "$LastSuccessfulMessage" ]; then
        echo "$LastSuccessfulMessage"
    fi
}

print_errors() {
    echo 
    #grep -E "ANE4007E|ANR2579E|ANR0522W|ANR2578W" "$ClientFile" | sed 's;^\([0-9]*\)/\([0-9]*\)/\([0-9]*\)\(.*\);\3-\1-\2\4;'
    ERRORS="$(grep -E "ANE4007E|ANR2579E|ANR0522W|ANR2578W" "$ClientFile" | sed -r 's;^([0-9]{2})/([0-9]{2})/([0-9]{4})(.*);\3-\1-\2\4;')"
    WierdChars=$(grep -c ANE4042E "$ClientFile")
    if [ -n "$ERRORS" ]; then
        printf "${ESC}${BoldFace}mErrors and warnings:${Reset} ${ESC}${ItalicFace}m(Note that not all errors are reported! For full details, see the details file)${Reset}\n"
        echo "$ERRORS"
        if [ $WierdChars -gt 0 ]; then
            printf "%-15s%'11d%-70s" "Additionally," "$WierdChars" "files have file names containing one or more unrecognized characters"
        fi
    else
        if [ $WierdChars -gt 0 ]; then
            printf "${ESC}${BoldFace}mErrors and warnings:${Reset} ${ESC}${ItalicFace}m(Note that not all errors are reported! For full details, see the details file)${Reset}\n"
            printf "%-'10d%-70s" "$WierdChars" "files have file names containing one or more unrecognized characters" | sed -r 's/ +/ /g'
            echo
        fi
    fi
}


#   _____   _   _  ______       _____  ______      ______   _   _   _   _   _____   _____   _____   _____   _   _   _____ 
#  |  ___| | \ | | |  _  \     |  _  | |  ___|     |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  | |__   |  \| | | | | |     | | | | | |_        | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--. 
#  |  __|  | . ` | | | | |     | | | | |  _|       |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  | |___  | |\  | | |/ /      \ \_/ / | |         | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/  \_| \_/ |___/        \___/  \_|         \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/ 
#


# Find the location of the script
ScriptNameLocation

# Get the secret password, either from the users home-directory or the script-dir
if [ -f ~/.tsm_secrets.env ]; then
    source ~/.tsm_secrets.env
else
    source "$ScriptDirName"/tsm_secrets.env
fi

# See that the node exists
check_node_exists

print_header

# Get client info (version, IP-address and such)
client_info
print_client_info

# Get the activity log for today (saves time to do it only one)
get_backup_data

# Look for completion of backup
backup_result

# Look for errors:
error_detection

# Print the result
print_result

# Print certain error messages
print_errors

echo
printf "${ESC}${ItalicFace}mDetails are in the file $ClientFile${Reset}\n"
