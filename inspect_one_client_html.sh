#!/bin/bash
# Get detailed info for a single client using the activity log
# 2022-09-06 / PM
# Department of Computer Science, Lund University


client=$1
if [ -z "$client" ]; then
    echo "No client slected. Exiting..."
    exit 1
fi

# Where the result should be stored locally
OutDirPrefix="/tmp/tsm"
OutDir="$OutDirPrefix/${SELECTION/_/\/}"                 # Ex: OutDir=/tmp/tsm/cs/clients
ClientFile="$OutDirPrefix/${client,,}.out"
ReportFile="$OutDir/${client,,}.html"                    # Ex: ReportFile=/tmp/tsm/cs/clients/cs-petermac.html
ConflictedText="<em>(A backup </em>has<em> been performed, but a <a href=\"https://www.ibm.com/docs/en/spectrum-protect/8.1.16?topic=list-anr0010w#ANR2579E\" target=\"_blank\" rel=\"noopener noreferrer\">ANR2579E</a> has been thrown, erroneously indicating “no backup”)</em>"

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
        ScriptDirName="$(dirname "${BASH_SOURCE[0]}")"                 # ScriptDirName=/home/cs-pmo/tsm-server-report
        # What is the name of the script?
        ScriptName="$(basename "${BASH_SOURCE[0]}")"                   # ScriptName=inspect_one_client_html.sh
    fi
    ScriptFullName="${ScriptDirName}/${ScriptName}"                    # ScriptFullName=/home/cs-pmo/tsm-server-report/inspect_one_client_html.sh
}

check_node_exists() {
    ClientInfo="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query node $client f=d")"
    ClientES=$?
    ServerName="$(echo "$ClientInfo" | grep -E "^Session established with server" | cut -d: -f1 | awk '{print $NF}')"
    #if [ $(echo "$ServerResponse" | grep -E "^ANS8002I" | awk '{print $NF}' | cut -d. -f1) -ne 0 ]; then
    if [ $ClientES -eq 11 ]; then
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
}

get_header() {
    cat "${ScriptDirName}/report_one_head.html"  | sed "s/CLIENT_NAME/$client/g" | sed "s/REPORT_DATE/$(date +%F)/" | sed "s/REPORT_TIME/$(date +%H:%M)/" > "$ReportFile"
    chmod 644 "$ReportFile"
}

client_info() {
    ClientVersion="$(echo "$ClientInfo" | grep -E "^\s*Client Version:" | cut -d: -f2 | sed -e 's/ Version //' -e 's/, release /./' -e 's/, level /./')"   # Ex: ClientVersion='8.1.13'
    ClientLastNetworkTemp="$(echo "$ClientInfo" | grep -Ei "^\s*TCP/IP Address:" | cut -d: -f2 | sed -e 's/^ //')"                                         # Ex: ClientLastNetworkTemp='10.7.58.184'
    case "$(echo "$ClientLastNetworkTemp" | cut -d\. -f1-2)" in
        "130.235") ClientLastNetwork="LU" ;;
        "10.4")    ClientLastNetwork="Static VPN" ;;
        "10.7")    ClientLastNetwork="eduroam (staff)" ;;
        "10.8")    ClientLastNetwork="eduroam (stud.)" ;;
        "10.9")    ClientLastNetwork="eduroam (other)" ;;
        "" )       ClientLastNetwork="Unknown" ;;
        #* )        ClientLastNetwork="outside LU" ;;
        * )        ClientLastNetwork="$ClientLastNetworkTemp" ;;
    esac
    case "$(echo "$ClientLastNetworkTemp" | cut -d\. -f1-3)" in
        "130.235.16" ) ClientLastNetwork="CS server net" ;;
        "130.235.17" ) ClientLastNetwork="CS server net" ;;
        "10.0.16"    ) ClientLastNetwork="CS client net" ;;
    esac
    #if [ -z "$ClientLastNetwork" ]; then
        #ClientLastNetwork="$ClientLastNetworkTemp"
    #fi
    TransportMethod="$(echo "$ClientInfo" | grep -E "^\s*Transport Method:" | cut -d: -f2 | sed 's/^ *//')"
    ClientOS="$(echo "$ClientInfo" | grep -Ei "^\s*Client OS Name:" | cut -d: -f3 | sed -e 's/Microsoft //' -e 's/ release//' | cut -d\( -f1)"
    # Ex: ClientOS='Macintosh' / 'Ubuntu 20.04.4 LTS' / 'Windows 10 Education' / 'Fedora release 36' / 'Debian GNU/Linux 10' / 'CentOS Linux 7.9.2009'
    if [ "$ClientOS" = "Macintosh" ]; then
        ClientOSLevel="$(echo "$ClientInfo" | grep -Ei "^\s*Client OS Level:" | cut -d: -f2 | sed 's/^\ //')"                                  # Ex: ClientOSLevel='10.16.0'
        # Get a full name for the version (see https://en.wikipedia.org/wiki/Darwin_(operating_system)):
        case "${ClientOSLevel:0:5}" in
            10.10) ClientOS="OS X ${ClientOSLevel} “Yosemite”" ;;
            10.11) ClientOS="OS X ${ClientOSLevel} “El Capitan”" ;;
            10.12) ClientOS="macOS ${ClientOSLevel} “Sierra”" ;;
            10.13) ClientOS="macOS ${ClientOSLevel} “High Sierra”" ;;
            10.14) ClientOS="macOS ${ClientOSLevel} “Mojave”" ;;
            10.15) ClientOS="macOS ${ClientOSLevel} “Catalina”" ;;
            11.*) ClientOS="macOS ${ClientOSLevel} “Big Sur”" ;;
            12.*) ClientOS="macOS ${ClientOSLevel} “Monterey”" ;;
            10.16) ClientOS="macOS ${ClientOSLevel} “Ventura”" ;;
            *) ClientOS="macOS ($ClientOSLevel)" ;;
        esac
    fi
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
    # Deal with dates in US format (MM/DD/YY):
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
    ClientCanDeleteBackup="$(echo "$ClientInfo" | grep -E "^\s*Backup Delete Allowed\?:" | cut -d: -f2 | sed 's/^ *//')"
    # Add the occupancy data to the ClientFile:
    echo "$ClientOccupancy" >> $ClientFile
    # Add filespace information to the ClientFile
    echo "" >> $ClientFile
    echo "$ClientFilespaces" >> $ClientFile
    echo "" >> $ClientFile
}

# Print client info
print_client_info()
{
    echo "        <tr><th colspan=\"2\">Information about the node</th></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Contact:</i></td><td align=\"left\">$ContactName</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Email address:</i></td><td align=\"left\">$ContactEmail</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Node registered by:</i></td><td align=\"left\">${NodeRegisteredBy:--unknown-} on ${NodeRegisteredDate:--unknown-}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><div class=\"tooltip\"><i>Policy Domain:</i><span class=\"tooltiptext\">A “policy domain” is an organizational way to group backup clients that share common backup requirements</span></div></td><td align=\"left\">${PolicyDomain:--unknown-}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><div class=\"tooltip\"><i>Cloptset:</i><span class=\"tooltiptext\">A “cloptset” (client option set) is a set of rules, defined on the server, that determines what files and directories are <em>excluded</em> from the backup</span></div><td align=\"left\">${CloptSet:--unknown-}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><div class=\"tooltip\"><i>Schedule:</i><span class=\"tooltiptext\">A “schedule” is a time window during which the server and the client, in collaboration and by using chance, determines a time for backup to be performed</span></div></td><td align=\"left\">${Schedule:--unknown-} ($ScheduleStart ${ScheduleDuration,,})</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Transport Method:</i></td><td align=\"left\">${TransportMethod:-unknown}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Connected to Server:</i></td><td align=\"left\">${ServerName:--}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><div class=\"tooltip\"><i>Can delete backup:</i><span class=\"tooltiptext\">Says whether or not a client node can delete files from it’s own backup</span></div></td><td align=\"left\">${ClientCanDeleteBackup}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Client version:</i></td><td align=\"left\">$ClientVersion</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Client OS:</i></td><td align=\"left\">$ClientOS</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Client last access:</i></td><td align=\"left\">${ClientLastAccess:-no info}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Client last network:</i></td><td align=\"left\">${ClientLastNetwork:-no info}</td></tr>" >> $ReportFile
}

# Get the activity log for today (saves time to do it only one)
# Do not include ANR2017I ('Administrator ADMIN issued command...')
get_backup_data() {
    dsmadmc -id=$ID -password=$PASSWORD -TABdelimited "query actlog begindate=today$DaysBack enddate=today endtime=now" | grep -Ei "\s$client[ \)]" | grep -v "ANR2017I" >> $ClientFile
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

    # So, did it end successfully?
    if [ -n "$(grep ANR2507I $ClientFile | grep "completed successfully" | tail -1)" ]; then
        BackupStatus="Successful"
    else
        BackupStatus="ERROR"
    fi
}

error_detection() {
    if [ -n "$(grep ANE4007E "$ClientFile")" ]; then
        NumErr=$(grep -c ANE4007E "$ClientFile")
        ErrorMsg+="$NumErr <a href=\"https://www.ibm.com/docs/en/spectrum-protect/8.1.17?topic=list-ane4000e#ANE4007E\" target=\"_blank\" rel=\"noopener noreferrer\">ANE4007E</a> (access denied to object)<br>"
    fi
    if [ -n "$(grep ANR2579E "$ClientFile")" ]; then
        ErrorCodes="$(grep ANR2579E "$ClientFile" | grep -Eio "\(return code -?[0-9]*\)" | sed -e 's/(//' -e 's/)//' | sort -u | tr '\n' ',' | sed -e 's/,c/, c/g' -e 's/,$//')"
        NumErr=$(grep -c ANR2579E "$ClientFile")
        ErrorMsg+="$NumErr <a href=\"https://www.ibm.com/docs/en/spectrum-protect/8.1.16?topic=list-anr0010w#ANR2579E\" target=\"_blank\" rel=\"noopener noreferrer\">ANR2579E</a> ($ErrorCodes)<br>"
    fi
    if [ -n "$(grep ANR0424W "$ClientFile")" ]; then
        NumErr=$(grep -c ANR0424W "$ClientFile")
        ErrorMsg+="$NumErr <a href=\"https://www.ibm.com/docs/en/spectrum-protect/8.1.16?topic=list-anr0010w#ANR0424W\" target=\"_blank\" rel=\"noopener noreferrer\">ANR0424W</a> (invalid password submitted)<br>"
    fi
    if [ -n "$(grep ANE4042E "$ClientFile")" ]; then
        NumErr=$(grep -c ANE4042E "$ClientFile")
        ErrorMsg+="$(printf "%'d" $NumErr) <a href=\"https://www.ibm.com/docs/en/spectrum-protect/8.1.17?topic=list-ane4000e#ANE4042E\" target=\"_blank\" rel=\"noopener noreferrer\">ANS4042E</a> (unrecognized characters)<br>"
    fi
}

# Print the result
print_result() {
    # Fix the strange situation where a backup has taken place but Return code 12 says it hasn't
    if [ "$BackupStatus" = "ERROR" ] && [ -n "$BackedupNumfiles" ] && [ -n "$TransferredVolume" ] && [ -n "$BackeupElapsedtime" ]; then
        BackupStatus="Conflicted!!<br>$ConflictedText"
    fi
    # Get time period in a more human form
    if [ "$DaysBack" = " begintime=00:00:00" ]; then
        #printf "${ESC}${InvertColor}mBackup-report for client \"$client\" on $(date +%F" "%T). Period: today${Reset}\n"
        PeriodString="today"
    else
        PeriodString="last ${DaysBack/-/} day$([[ ${DaysBack/-/} -gt 1 ]] && echo "s")"
    fi

    # Print information about the backup the specified time period:
    echo "        <tr><th colspan=\"2\">Information about backup $PeriodString:</th></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Backup Status:</i></td><td align=\"left\">${BackupStatus/ERROR/NO BACKUP FOUND}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Nbr. files:</i></td><td align=\"left\">${BackedupNumfiles:-0}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Bytes transferred:</i></td><td align=\"left\">$TransferredVolume</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Time elapsed:</i></td><td align=\"left\">$BackeupElapsedtime</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Backup concluded:</i></td><td align=\"left\">$LastFinishDate $LastFinishTime</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Errors encountered:</i></td><td align=\"left\">$(echo "$ErrorMsg" | sed 's/<br>$//')</td></tr>" >> $ReportFile
    echo "      </tbody>" >> $ReportFile
    echo "    </table>" >> $ReportFile
    echo "    <p>&nbsp;</p>" >> $ReportFile


    # Print info about the client on the server
    echo "    <table id=\"information\">" >> $ReportFile
    echo "      <thead>" >> $ReportFile
    echo "        <tr><th colspan=\"7\">Client usage of server resources:</th></tr>" >> $ReportFile
    echo "      </thead>" >> $ReportFile
    echo "      <tbody>" >> $ReportFile
    echo "        <tr><td><i>Filespace Name</i></td><td align=\"right\"><i>FSID</i></td><td><i>Type</i></td><td align=\"right\"><i>Nbr files</i></td><td align=\"right\"><i>Space Occupied [MB]</i></td><td><i>Last backup</i></td><td><i>Days ago</i></td> </tr>" >> $ReportFile

    for fsid in $FSIDs
    do
        FSName=""
        NbrFiles=0
        SpaceOccup=0
        OccupInfo="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query occupancy $client $fsid nametype=fsid")"
        FSInfo="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query filespace $client $fsid nametype=fsid f=d")"
        FSName="$(echo "$OccupInfo" | grep -E "^\s*Filespace Name:" | cut -d: -f2 | sed 's/^\ //')"
        FSType="$(echo "$FSInfo" | grep -E "^\s*Filespace Type:" | cut -d: -f2 | sed 's/^\ //')"                                                # Ex: FSType=EXT4
        NbrFiles="$(echo "$OccupInfo" | grep -E "^\s*Number of Files:" | cut -d: -f2 | sed 's/^\ //' | cut -d\. -f1)"
        SpaceOccup="$(echo "$OccupInfo" | grep -E "Space Occupied" | cut -d: -f2 | grep -v "-" | tail -1 | sed 's/\ //' | cut -d\. -f1)"
        LastBackupDate="$(echo "$FSInfo" | grep -E "Last Backup Completion Date/Time:" | cut -d: -f2 | awk '{print $1}')"      # Ex: LastBackupDate=11/28/22
        if [ "$(echo "$LastBackupDate" | cut -c3,6)" = "//" ]; then
            LastBackupDate="20${LastBackupDate:6:2}-${LastBackupDate:0:2}-${LastBackupDate:3:2}"
        fi
        LastBackupNumDays="$(echo "$FSInfo" | grep -E "Days Since Last Backup Completed:" | cut -d: -f2 | awk '{print $1}' | sed 's/[,<]//g')"   # Ex: LastBackupNumDays='<1'
        echo "        <tr><td align=\"left\"><code>${FSName:-no name}</code></td><td align=\"right\"><code>$fsid</code></td><td><code>${FSType:--??-}</code></td><td align=\"right\">${NbrFiles:-0}</td><td align=\"right\">${SpaceOccup:-0}</td><td>${LastBackupDate}</td><td align=\"right\">${LastBackupNumDays:-0}</td></tr>" >> $ReportFile
    done
    echo "      </tbody>" >> $ReportFile
    echo "    </table>" >> $ReportFile
    echo "  </section>" >> $ReportFile
        if [ -n "$LastSuccessfulMessage" ]; then
            echo "$LastSuccessfulMessage"
        fi
    }

print_documentation() {
    case "$(echo "$ClientOS" | awk '{print $1}' | tr [:upper:] [:lower:])" in
        "macos" ) LogFile="<code>/Library/Logs/tivoli/tsm</code>" ;;
        "windows" ) LogFile="<code>C:\TSM</code>&nbsp;or&nbsp;<code>C:\Program Files\Tivoli\baclient</code>" ;;
        * ) LogFile="<code>/var/log/tsm</code>&nbsp;or&nbsp;<code>/opt/tivoli/tsm/client/ba/bin</code>" ;;
    esac

    echo "  <p>&nbsp;</p>" >> $ReportFile
    echo "  <section>" >> $ReportFile
    echo "    <div id="box-documentation">" >> $ReportFile
    echo "      <h4>Documentation:</h4>" >> $ReportFile
    echo "      <div class="flexbox-container">" >> $ReportFile
    echo "        <table id="explanations">" >> $ReportFile
    echo "          <tr>" >> $ReportFile
    echo "            <td colspan="2"><p><img src="https://fileadmin.cs.lth.se/intern/backup/cs/pdf.svg" width="70" height="70" alt="PDF-icon"></p></td>" >> $ReportFile
    echo "            <td><div align="left">" >> $ReportFile
    echo "                <p>&#10132;&nbsp;<a href="https://lthin.lth.lu.se/download/18.5b76e7a8184b9280a4a18e5d/1669975867674/About_the_Spectrum_Protect_Backup.pdf" target="_blank" rel="noopener noreferrer">About the Spectrum Protect Backup</a></p>" >> $ReportFile
    echo "                <p>&#10132;&nbsp;<a href="https://lthin.lth.lu.se/download/18.5b76e7a8184b9280a4a18e5e/1669975867713/How_to_restore_files_from_the_Spectrum_Protect_backup.pdf" target="_blank" rel="noopener noreferrer">Restore files (GUI)</a></p>" >> $ReportFile
    echo "                <p>&#10132;&nbsp;<a href="https://lthin.lth.lu.se/download/18.5b76e7a8184b9280a4a18e5f/1669975867746/How_to_restore_files_from_the_Spectrum_Protect_backup_using_CLI.pdf" target="_blank" rel="noopener noreferrer">Restore files (CLI)</a></p>" >> $ReportFile
    echo "                <p>&#10132;&nbsp;<a href="https://lthin.lth.lu.se/download/18.5b76e7a8184b9280a4a18e60/1669975867763/Deselect_files_from_the_Spectrum_Protect_Backup.pdf" target="_blank" rel="noopener noreferrer">Deselect files from backup</a></p>" >> $ReportFile
    echo "                <p>&#10132;&nbsp;<a href="https://lthin.lth.lu.se/download/18.1a60868218529b3dca391a8e/1673615105281/Installing_the_client.pdf" target="_blank" rel="noopener noreferrer">Installing the Spectrum Protect Backup client</a></p>" >> $ReportFile
    echo "              </div></td>" >> $ReportFile
    echo "          </tr>" >> $ReportFile
    echo "          <tr>" >> $ReportFile
    echo "            <td colspan="3">&nbsp;</td>" >> $ReportFile
    echo "          </tr>" >> $ReportFile
    echo "          <tr>" >> $ReportFile
    echo "            <td colspan="3"><p align="left">Details can be found in the local log file, <code>dsmsched.log</code>,<br>found in $LogFile</p></td>" >> $ReportFile
    echo "          </tr>" >> $ReportFile
    echo "        </table>" >> $ReportFile
    echo "      </div>" >> $ReportFile
    echo "    </div>" >> $ReportFile
    echo "  </section>" >> $ReportFile
}

print_footer() {
    echo "  <footer>" >> $ReportFile
    echo "    <p>&nbsp;</p>" >> $ReportFile
    echo "    <div id=\"box1\">" >> $ReportFile
    echo "      <table>" >> $ReportFile
    echo "        <tr>" >> $ReportFile
    echo "          <td><p><img src=\"https://fileadmin.cs.lth.se/intern/backup/cs/settings_icon.svg\" width=\"40\" alt=\"Settings-icon\">&nbsp;&nbsp;</p></td>" >> $ReportFile
    echo "          <td><p align=\"left\"><em>For admins only:</em><br>" >> $ReportFile
    echo "            <a href=\"https://$OC_SERVER/oc/gui#clients/detail?server=${ServerName}&resource=${client}&vmOwner=%20&target=%20&type=1&nodeType=1&ossm=0&nav=overview\" target=\"_blank\" rel=\"noopener noreferrer\">Linkt to admin server</a></p>" >> $ReportFile
    echo "          </td>" >> $ReportFile
    echo "        </tr>" >> $ReportFile
    echo "      </table>" >> $ReportFile
    echo "    </div>" >> $ReportFile
    echo "  </footer>" >> $ReportFile
    echo "</div>" >> $ReportFile
    echo "</body>" >> $ReportFile
    echo "</html>" >> $ReportFile
}

#   _____   _   _  ______       _____  ______      ______   _   _   _   _   _____   _____   _____   _____   _   _   _____ 
#  |  ___| | \ | | |  _  \     |  _  | |  ___|     |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  | |__   |  \| | | | | |     | | | | | |_        | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--. 
#  |  __|  | . ` | | | | |     | | | | |  _|       |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  | |___  | |\  | | |/ /      \ \_/ / | |         | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/  \_| \_/ |___/        \___/  \_|         \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/ 
#


# Find the location of the script:
ScriptNameLocation

# Get the secret password, either from the users home-directory or the script-dir:
if [ -f ~/.tsm_secrets.env ]; then
    source ~/.tsm_secrets.env
else
    source "$ScriptDirName"/tsm_secrets.env
fi

# See that the node exists:
check_node_exists

get_header

# Get client info (version, IP-address and such):
client_info
print_client_info

# Get the activity log for today (saves time to do it only one):
get_backup_data

# Look for completion of backup:
backup_result

# Look for errors:
error_detection

# Print the result:
print_result

# Print certain error messages:
print_documentation

# Print the end:
print_footer

# Copy result if SCP=true
if $SCP; then
    scp "$ReportFile" "${SCP_USER}@${SCP_HOST}:${SCP_DIR}${SELECTION/_/\/}/${client,,}.html" &>/dev/null
fi
