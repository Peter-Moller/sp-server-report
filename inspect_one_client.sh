#!/bin/bash
# Get detailed info for a single client using the activity log
# 2022-09-06 / PM
# Department of Computer Science, Lund University

# Currently, it digs through machines that are manually specified in lists in the script. 
# The plan is to instead have the user provide either POLICYDOMAIN och a SCHEDULE and then
# get the client list from those and produce result accoringly.

# Get the secret password
source /opt/monitoring/tsm_secrets.env 

CLIENT=$1
if [ -z "$CLIENT" ]; then
    echo "No client slected. Exiting..."
    exit 1
fi
ClientFile="/tmp/${CLIENT}.out"

RANGE=$2
if [ -z "$RANGE" ]; then
    DaysBack=" begintime=00:00:00"
else
    DaysBack="-$RANGE"
fi

Reset="\e[0m"
ESC="\e["
ItalicFace="3"
BoldFace="1"
InvertColor="7"

# Set LANG to Swedish so that all dates are in intelligent format...
export LANG=sv_SE.UTF-8

Client_W="%-13s"
BackedupNumfiles_H="%11s"
BackedupNumfiles_W="%'11d"
TransferredVolume_W="%13s"
BackeupElapsedtime_W="%-10s"
BackupStatus_W="%-15s"
ClientTotalSpaceUseMB_WH="%10s"
ClientTotalSpaceUsedMB_W="%'10d"
ClientTotalNumFile_WH="%11s"
ClientTotalNumFiles_W="%'11d"
ClientVersion_W="%-9s"
ClientLastNetWork_W="%-18s"
ClientOS_W="%-23s"
ErrorMsg_W="%-60s"

FormatStringHeader="${Client_W}${BackedupNumfiles_H}${TransferredVolume_W}  ${BackeupElapsedtime_W}${BackupStatus_W}${ClientTotalNumFile_WH}  ${ClientTotalSpaceUseMB_WH}  ${ClientVersion_W}${ClientLastNetWork_W}${ClientOS_W}${ErrorMsg_W}"
FormatStringConten="${Client_W}${BackedupNumfiles_W}${TransferredVolume_W}  ${BackeupElapsedtime_W}${BackupStatus_W}${ClientTotalNumFiles_W}  ${ClientTotalSpaceUsedMB_W}  ${ClientVersion_W}${ClientLastNetWork_W}${ClientOS_W}${ErrorMsg_W}"

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
    if [ "$DaysBack" = " begintime=00:00:00" ]; then
        printf "${ESC}${InvertColor}mBackup-report for client \"$CLIENT\" on $(date +%F" "%T). Period: today${Reset}\n"
    else
        printf "${ESC}${InvertColor}mBackup-report for client \"$CLIENT\" on $(date +%F" "%T). Period: last ${DaysBack/-/} day$([[ ${DaysBack/-/} -gt 1 ]] && echo "s")${Reset}\n"
    fi
    #printf "${ESC}${InvertColor}mContact: \"${ContactName:--none-}\". Node was registered ${NodeRegistered:--unknown-}. Policy Domain: ${PolicyDomain:--unknown-}. Cloptset: ${CloptSet:--unknown-}${Reset}\n"
    printf "${ESC}${ItalicFace}mContact:$Reset \"${ContactName:--none-}\".${ESC}${ItalicFace}m Node was registered:$Reset ${NodeRegistered:--unknown-}.${ESC}${ItalicFace}m Policy Domain:$Reset ${PolicyDomain:--unknown-}.${ESC}${ItalicFace}m Cloptset:$Reset ${CloptSet:--unknown-}.${ESC}${ItalicFace}m Schedule:$Reset ${Schedule:--unknown-} ($ScheduleStart $ScheduleDuration)\n"
    echo
    #printf "${ESC}${BoldFace}m$FormatStringHeader${Reset}\n" "Client name" "NumFiles" "Transferred" "Time" "Status" " ∑ files" "Total [MB]" "Version" "Client network" "Client OS" "Errors"
    printf "${ESC}${BoldFace}m$FormatStringHeader${Reset}\n" "Client " "Number" "Bytes" "Time" "Backup" " ∑ files" "   Sum MB on" "Client" "Client" "Client" "Errors"
    printf "${ESC}${BoldFace}m$FormatStringHeader${Reset}\n" "name" "of files" "transf." "elapsed" "status" " on server" "server" "version" "network" "operating system" "encountered"
}

check_node_exists() {
    ClientInfo="$(dsmadmc -id=$id -password=$pwd -DISPLaymode=LISt "q node $CLIENT f=d")"
    ClientES=$?
    #if [ $(echo "$ServerResponse" | grep -E "^ANS8002I" | awk '{print $NF}' | cut -d. -f1) -ne 0 ]; then
    if [ $ClientES -eq 11 ]; then
        echo "Client \"$CLIENT\" does not exist on server \"$ServerName\". Exiting..."
        exit 1
    else
        ServerName="$(echo "$ClientInfo" | grep -E "^Session established with server" | cut -d: -f1 | awk '{print $NF}')"
        ContactName="$(echo "$ClientInfo" | grep -E "^\s*Contact:" | cut -d: -f2 | sed 's/^ *//')"
        #NodeRegistered="$(echo "$ClientInfo" | grep -E "^\s*Registration Date/Time:" | cut -d: -f2- | sed 's/^ *//' | sed -r 's;^([0-9]{2})/([0-9]{2})/([0-9]{4})(.*);\3-\1-\2;')"
        NodeRegistered="$(echo "$ClientInfo" | grep -E "^\s*Registration Date/Time:" | cut -d: -f2- | sed 's/^ *//' | awk '{print $1}')"
        PolicyDomain="$(echo "$ClientInfo" | grep -E "^\s*Policy Domain Name:" | cut -d: -f2 | sed 's/^ *//')"
        CloptSet="$(echo "$ClientInfo" | grep -E "^\s*Optionset:" | cut -d: -f2 | sed 's/^ *//')"
        Schedule="$(dsmadmc -id=$id -password=$pwd -DISPLaymode=LISt "query association * *" | grep -i -B1 "$CLIENT" | head -1 | awk '{print $NF}')"
        ScheduleStart="$(dsmadmc -id=$id -password=$pwd -DISPLaymode=LISt "q schedule $PolicyDomain $Schedule f=d" | grep -E "^\s*Start Date/Time:" | awk '{print $NF}')"
        ScheduleDuration="+ $(dsmadmc -id=$id -password=$pwd -DISPLaymode=LISt "q schedule $PolicyDomain $Schedule f=d" | grep -E "^\s*Duration:" | cut -d: -f2 | sed 's/^ *//')"
    fi
}

client_info() {
    printf "..... gathering client info (1/4) ....."
    #ClientInfo="$(dsmadmc -id=$id -password=$pwd -DISPLaymode=LISt "q node $CLIENT f=d")"
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
    ClientOS="$(echo "$ClientInfo" | grep -Ei "^\s*Client OS Name:" | cut -d: -f3 | sed -e 's/Microsoft //' -e 's/ release//' | cut -d\( -f1)"
    # Ex: ClientOS='Macintosh' / 'Ubuntu 20.04.4 LTS' / 'Windows 10 Education' / 'Fedora release 36' / 'Debian GNU/Linux 10' / 'CentOS Linux 7.9.2009'
    ClientTotalSpaceUsedMB="$(dsmadmc -id=$id -password=$pwd -DISPLaymode=LISt "query occupancy $CLIENT" | grep -E  "^\s*Physical Space Occupied" | cut -d: -f2 | cut -d, -f1 | sed 's/ //g' | awk '{ sum+=$1 } END {print sum}' | cut -d. -f1)"
    ClientTotalNumFiles="$(dsmadmc -id=$id -password=$pwd -DISPLaymode=LISt "query occupancy $CLIENT" | grep -E  "^\s*Number of Files" | cut -d: -f2 | cut -d, -f1 | sed 's/ //g' | awk '{ sum+=$1 } END {print sum}')"
    printf "${ESC}40D"
}

# Get the activity log for today (saves time to do it only one)
# Do not include ANR2017I ('Administrator ADMIN issued command...')
get_backup_data() {
    printf "..... gathering backup data (2/4) ....."
    dsmadmc -id=$id -password=$pwd -TABdelimited "q act begindate=today$DaysBack enddate=today endtime=now" | grep -Ei "\s$CLIENT[ \)]" | grep -v "ANR2017I" > $ClientFile
    printf "${ESC}40D"
}

backup_result() {
    # Number of files:
    # (note that some client use a unicode 'non breaking space', e280af, as thousands separator. This must be dealt with!)
    # (also, note that some machines will have more than one line of reporting. We only consider the last one)
    printf "..... getting backup results (3/4) ....."
    BackedupNumfiles="$(grep ANE4954I $ClientFile | sed -e 's/\xe2\x80\xaf/,/' | grep -Eo "Total number of objects backed up:\s*[0-9,]*" | awk '{print $NF}' | sed -e 's/,//g' | tail -1)"  # Ex: BackedupNumfiles='3483'
    TransferredVolume="$(grep ANE4961I $ClientFile | grep -Eo "Total number of bytes transferred:\s*[0-9,.]*\s[KMG]?B" | tail -1 | cut -d: -f2 | sed -e 's/\ *//' | tail -1)"               # Ex: TransferredVolume='1,010.32 MB'
    BackeupElapsedtime="$(grep ANE4964I $ClientFile | grep -Eo "Elapsed processing time:\s*[0-9:]*" | tail -1 | awk '{print $NF}' | tail -1)"                                               # Ex: BackeupElapsedtime='00:46:10'
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
        BackupStatus="NO BACKUP FOUND"
    fi
    printf "${ESC}41D"
}

error_detection() {
    printf "..... looking for errors (4/4) ....."
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

# Print the result
print_line() {
    printf "${ESC}27D"
    # Fix the strange situation where a backup has taken place but Return code 12 says it hasn't
    if [ "$BackupStatus" = "ERROR" ] && [ -n "$BackedupNumfiles" ] && [ -n "$TransferredVolume" ] && [ -n "$BackeupElapsedtime" ]; then
        BackupStatus="Conflicted!!"
    fi
    printf "$FormatStringConten\n" "$CLIENT" "$BackedupNumfiles" "$TransferredVolume" "$BackeupElapsedtime" "${BackupStatus/ERROR/- NO BACKUP -}" "$ClientTotalSpaceUsedMB" "$ClientTotalNumFiles" "$ClientVersion" "$ClientLastNetwork" "$ClientOS" "${ErrorMsg%; }"
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

# See that the node exists
check_node_exists

print_header

# Get client info (version, IP-address and such)
client_info

# Get the activity log for today (saves time to do it only one)
get_backup_data

# Look for completion of backup
backup_result

# Look for errors:
error_detection

# Print the result
print_line

# Print certain error messages
print_errors

echo
printf "${ESC}${ItalicFace}mDetails are in the file $ClientFile${Reset}\n"
