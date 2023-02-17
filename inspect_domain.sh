#!/bin/bash
# Get detailed info for clients using the activity log
# 2022-11-11 / Peter Möller
# Department of Computer Science, Lund University

# 'DOMAIN' is the domain or domains to be reported. 
# It is assumed to be a single domain such as CS_CLIENTS, but may be more.
export DOMAIN="$(echo "$@" | tr '[:upper:]' '[:lower:]')"  # Ex: DOMAIN='cs_clients'

# We must, however, have at least one domain to go through
if [ -z "$DOMAIN" ]; then
    echo "No input…"
    exit 1
fi

# Find out where the script resides
# Get the DirName and ScriptName
if [ -L "${BASH_SOURCE[0]}" ]; then
    # Get the *real* directory of the script
    ScriptDirName="$(dirname "$(readlink "${BASH_SOURCE[0]}")")"   # ScriptDirName='/usr/local/bin'
    # Get the *real* name of the script
    ScriptName="$(basename "$(readlink "${BASH_SOURCE[0]}")")"     # ScriptName=inspect_all_clients
else
    ScriptDirName="$(dirname "${BASH_SOURCE[0]}")"                 # ScriptDirName=/home/cs-pmo/tsm-server-report
    # What is the name of the script?
    ScriptName="$(basename "${BASH_SOURCE[0]}")"                   # ScriptName=inspect_all_clients.sh
fi
ScriptFullName="${ScriptDirName}/${ScriptName}"                    # ScriptFullName=/home/cs-pmo/tsm-server-report/inspect_all_clients.sh

# Get the secret password, either from the users home-directory or the script-dir
if [ -f ~/.tsm_secrets.env ]; then
    source ~/.tsm_secrets.env
else
    source "$ScriptDirName"/tsm_secrets.env
fi

# Generate the list of clients ('CLIENTS') to traverse by going through the list of policy domains ('DOMAIN')
# Also, generate a explanatory string for the domains ('Explanation'):
for item in $DOMAIN; do
    # Test if the $item exists
    if dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LISt "query domain $item" &>/dev/null; then
        CLIENTStmp+="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=list "query node * domain=$item" | grep -E "^\s*Node Name:" | awk '{print $NF}')"
        # Ex: CLIENTStmp+='CS-ABRUCE
        #                  CS-DRIFTPC
        #                  CS-PETERMAC
        #                  CS-PMOLINUX
        #                  CS-TEST'
        CLIENTStmp+=$'\n'
        NumClientsTmp=$(echo "$CLIENTStmp" | sort -u | tr '\n' " " | wc -w)  # Ex: NumClients=5
        ##Explanation+="“$item ($(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=list  "query domain $item" | grep -E "^\s*Description:" | cut -d: -f2 | sed 's/^\ *//'), $NumClientsTmp nodes) & "
        Explanation+="“$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=list  "query domain $item" | grep -E "^\s*Description:" | cut -d: -f2 | sed 's/^\ *//')” ($NumClientsTmp nodes) & "
        # Ex: Explanation+='CS_CLIENTS (CS client domain) & '
    else
        Explanation+="Non-existing policy domain: $item & "
    fi
done

CLIENTS="$(echo "$CLIENTStmp" | sort -u | tr '\n' " ")"  # Ex: CLIENTS='CS-ABRUCE CS-DRIFTPC CS-PETERMAC CS-PMOLINUX CS-TEST '

# Exit if the list is empty
if [ -z "$CLIENTS" ]; then
    echo "No clients in the given domains (\"$DOMAIN\")! Exiting"
    exit 1
fi


# Some basic stuff
Today="$(date +%F)"                                                       # Ex: Today=2011-11-11
NowEpoch=$(date +%s)                                                      # Ex: NowEpoch=1662627432
Now="$(date +%H:%M)"                                                      # Ex: Now=15:40
MulSign="&#215;"                                                          # ×
OutDirPrefix="/var/tmp/tsm"
OutDir="$OutDirPrefix/${DOMAIN/_/\/}"                                     # Ex: OutDir=/var/tmp/tsm/cs/clients
# Create the OutDir if it doesn't exist:
# NOTE: it must be created manually on the web server (if it is used)!!!
if [ ! -d $OutDir ]; then
    mkdir -p $OutDir
fi
ActlogToday="$(mktemp)"
LinkReferer="target=\"_blank\" rel=\"noopener noreferrer\""
SP_WikipediaURL="https://en.wikipedia.org/wiki/IBM_Tivoli_Storage_Manager"
HTML_Template_Head="$ScriptDirName"/report_head.html
HTML_Template_End="$ScriptDirName"/report_end.html
HTML_Template_one_client_Head="$ScriptDirName"/report_one_head.html
HTML_Template_one_client_End="$ScriptDirName"/report_one_end.html
HTML_Error_Head="$ScriptDirName"/errors_head.html
ErrorIcon="&nbsp;&#x1F4E7;"                                               # Ex: 📧
ReportFileHTML="${OutDirPrefix}/${DOMAIN/_/\/}_${Today}.html"             # Ex: ReportFileHTML='/var/tmp/tsm/cs/servers_2022-11-11.html'
ErrorFile="${OutDirPrefix}/${DOMAIN/_/\/}_${Today}.errors"                # Ex: ErrorFile='/var/tmp/tsm/cs/servers_2022-11-11.errors'
ErrorFileHTML="${OutDirPrefix}/${DOMAIN/_/\/}_${Today}_errors.html"       # Ex: ErrorFile='/var/tmp/tsm/cs/servers_2022-11-11_errors.html'
SP_ErrorFile="$ScriptDirName"/sp_errors.txt                               # Super-important file containing all errors we want to be aware of. Needs to be updated as new errors are found
MainURL="${PUBLICATION_URL}/${DOMAIN/_/\/}"                               # Used for the 'sub-pages' (error.html and individual reports) to link back to the main overview page


#   _____   _____    ___   ______   _____       _____  ______      ______   _   _   _   _   _____   _____   _____   _____   _   _   _____ 
#  /  ___| |_   _|  / _ \  | ___ \ |_   _|     |  _  | |  ___|     |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  \ `--.    | |   / /_\ \ | |_/ /   | |       | | | | | |_        | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--. 
#   `--. \   | |   |  _  | |    /    | |       | | | | |  _|       |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  /\__/ /   | |   | | | | | |\ \    | |       \ \_/ / | |         | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/    \_/   \_| |_/ \_| \_|   \_/        \___/  \_|         \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/ 


server_info() {
    ServerInfo="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LISt "query status")"
    ServerVersion="$(echo "$ServerInfo" | grep -E "^\s*Server Version\s" | grep -Eo "[0-9]*" | tr '\n' '.' | cut -d\. -f1-3)"                                                                 # Ex: ServerVersion=8.1.16
    SP_WhatsNewURL="https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=servers-whats-new"
    SP_OverviewURL="https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=concepts-spectrum-protect-overview"
    ServerName="$(echo "$ServerInfo" | grep "Server Name:" | cut -d: -f2 | sed 's/^ //')"                                                                                                     # Ex: ServerName='TSM4'
    ActLogLength="$(echo "$ServerInfo" | grep "Activity Log Retention:" | cut -d: -f2 | awk '{print $1}')"                                                                                    # Ex: ActLogLength=30
    EventLogLength="$(echo "$ServerInfo" | grep "Event Record Retention Period:" | cut -d: -f2 | awk '{print $1}')"                                                                           # Ex: EventLogLength=14
    OC_URL="https://${OC_SERVER}/oc/gui#clients/detail?server=${ServerName}\&resource=BACKUPNODE\&vmOwner=%20\&target=%20\&type=1\&nodeType=1\&ossm=0\&nav=overview"
    # If we have a storage pool, get the data for usage
    if [ -n "$STORAGE_POOL" ]; then
        StgSizeGB="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=list "q stgpool $STORAGE_POOL" | grep "Estimated Capacity:" | awk '{print $3}' | sed 's/\xe2\x80\xaf/,/' | sed 's/,//g')"                     # Ex: StgSizeGB=276035
        StgSizeTB="$(echo "scale=0; $StgSizeGB / 1024" | bc -l)"                                                                                                                              # Ex: StgSizeTB=269
        StgUsage="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=list "q stgpool $STORAGE_POOL" | grep "Pct Util:" | awk '{print $NF}' )"                                             # Ex: StgUsage=2.9
        StorageText="($StgSizeTB TB, ${StgUsage}% used)"                                                                                                                                      # Ex: StorageText='(276 TB, 2.9% used)'
    fi
    
}

errors_today() {
    # Use informaiton from a text file, delimited by '|', with one error per row in this order:
    # Error | (DISREGARD) | Explanation | Email_text

    cat "$HTML_Error_Head" | sed "s/DOMAIN/$DOMAIN/g; s/DATE/$Today/g; s/TIME/$Now/" > "$ErrorFileHTML"

    # Check to see if any clients in the DOMAIN have had errors today
    # If not, we need to say that “All is well”
    ClientPipeList="$(echo "${CLIENTS// /|}" | sed 's/^|//; s/|$//')"                                                                                                                         # Ex: ClientPipeList='CS-COURSEGIT|CS-DOCKER|CS-DOKUWIKI|...'

    # Get a list of the errors that have occurred today [for the clients in this domain]:
    ErrorsInTheDailyLog="$(grep -E "AN[ER][0-9]{4}E" "$ActlogToday" | grep -E "$ClientPipeList" | grep -Eo "\bAN[^\)]*)" | awk '{print $1}' | sort -u)"
    # Ex: ErrorsInTheDailyLog='ANE4005E
    #                          ANE4007E
    #                          ANE4037E'

    # Go thropugh the list of errors [if there are any]
    if [ -n "$ErrorsInTheDailyLog" ]; then
        # Set standard values for email link:
        EmailGreetingText="Hi&excl;%0A%0AYou have a problem with your backup:%0AERROR (&#8220;REASON&#8221;).%0A(In the local log file, you may see this problem as &#8220;ANS...&#8221; but it is the same problem.)%0A"
        EmailLinkText="Here is a web page that descripes the error in more detail:%0A"
        EmailLinkTextIBM="Here is a web page at IBM that describes the error in more detail:%0A"
        EmailNoLinkText="We do not have a deeper description of this error."
        EmailEndText="Please contact us if you have any questions about this error.%0A%0Amvh,%0A/CS IT Staff"

        # Traverse this list and state what error it is and the clients affected
        # Make one table per error
        for ERROR in $ErrorsInTheDailyLog
        do
            ErrorText="$(grep $ERROR "$SP_ErrorFile" | cut -d\| -f3)"                                                                                                                         # Ex: ErrorText='Error processing '\''X'\'': file not found'
            IBM_Error_URL="$(grep $ERROR "$SP_ErrorFile" | cut -d\| -f4 | sed "s_SERVERVER_${ServerVersion}_")"                                                                               # Ex: IBM_Error_URL='https://www.ibm.com/docs/en/spectrum-protect/8.1.16?topic=list-anr0010w#ANR2579E'
            CS_Error_URL="$(grep $ERROR "$SP_ErrorFile" | cut -d\| -f5)"                                                                                                                      # Ex: CS_Error_URL='https://fileadmin.cs.lth.se/intern/backup/ANE4081E.html'
            if [ -n "$IBM_Error_URL" ]; then
                IBM_Link="<a href=\"$IBM_Error_URL\" $LinkReferer>Link to IBM</a>"                                                                                                            # Ex: IBM_Link='<a href="https://www.ibm.com/docs/en/spectrum-protect/8.1.16?topic=list-anr0010w#ANR2579E target="_blank" rel="noopener noreferrer">">IBM</a>'
            else
                IBM_Link=""
            fi
            # Make not of errors that are not noted in the public overview
            if [ -n "$(grep $ERROR "$SP_ErrorFile" | cut -d\| -f2 | grep -v REPORT)" ]; then
                DisregardText="<span style=\"color: #555\"><em>(not reported in the client overview)</em></span>"
                ErrorHeadText="<strong><em>$ERROR</em></strong>"
            else
                DisregardText=""
                ErrorHeadText="<strong>$ERROR</strong>"
            fi
            NewWindowIcon='<span class="glyphicon">&#xe164;</span>'
            echo "            <table id=\"errors\" style=\"margin-top: 1rem\">" >> "$ErrorFileHTML"
            if [ -n "$CS_Error_URL" ]; then
                InfoLink="<a href=\"$CS_Error_URL\" $LinkReferer>Local info.</a> $NewWindowIcon<br>$IBM_Link $NewWindowIcon"
            else
                if [ -n "$IBM_Link" ]; then
                    InfoLink="$IBM_Link $NewWindowIcon"
                else
                    InfoLink=""
                fi
            fi
            TableHeadLine="				<tr><td colspan=\"4\" bgcolor=\"#bad8e1\"><span class=\"head_fat\">$ErrorHeadText</span> $DisregardText<div class=\"right\">$InfoLink</div><br><span class=\"head_explain\">${ErrorText:-We have no explanation for this error}</span></td></tr>"
            echo "				<thead>" >> "$ErrorFileHTML"
            echo "$TableHeadLine" >> "$ErrorFileHTML"
            echo "				</thead>" >> "$ErrorFileHTML"
            echo "				<tbody>" >> "$ErrorFileHTML"
            # Get a list of nodes [in this domain] with the error we are currently looking at:
            CLIENTS_with_this_error="$(grep $ERROR "$ActlogToday" | grep -E "$ClientPipeList" | grep -Eo "[Nn]ode:?\ [A-Z0-9-]*" | awk '{print $NF}' | sort -u | tr '\n' ' ')"                # Ex: CLIENTS_with_this_error='CS-CHRISTOPHR CS-PMOLINUX '
            # Loop through the client list:
            for Node in $CLIENTS_with_this_error
            do
                NumUserErrors="$(grep $ERROR $ActlogToday | grep -c $Node)"                                                                                                                   # Ex: NumUserErrors=24
                NodeContact="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LIST "query node $Node f=d" | grep -E "^\s*Contact:" | cut -d: -f2 | sed 's/^ //')"                       # Ex: NodeContact='Jacek Malec'
                NodeEmail="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LIST "query node $Node f=d" | grep -E "^\s*Email Address:" | cut -d: -f2 | sed 's/^ //')"                   # Ex: NodeEmail=jacek.malec@cs.lth.se
                NodeOS="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LIST "query node $Node f=d" | grep -Ei "^\s*Client OS Name:" | cut -d: -f3 | sed 's/Microsoft //; s/ release//; s/Macintosh/macOS/' | cut -d\( -f1)"
                # Ex: ClientOS='macOS' / 'Ubuntu 20.04.4 LTS' / 'Windows 10 Education' / 'Fedora release 36' / 'Debian GNU/Linux 10' / 'CentOS Linux 7.9.2009'
                # Get a link for the error in question:
                if [ -n "$CS_Error_URL" ]; then
                    LinkDetailsText="%0A${EmailLinkText}${CS_Error_URL}%0A%0A"                                                                                                                # Ex: LinkDetailsText='Here is a web page that descripes the error in more detail: https://fileadmin.cs.lth.se/intern/backup/ANE4007E.html%0A%0A'
                else
                    LinkDetailsText="%0A${EmailLinkTextIBM}${IBM_Error_URL}%0A%0A"                                                                                                            # Ex: LinkDetailsText='Here is a web page at IBM that descripes the error in more detail: https://www.ibm.com/docs/en/spectrum-protect/SERVERVER?topic=list-ane4000e#ANE4005E%0A%0A'
                fi
                EmailBodyText="$(echo "$EmailGreetingText" | sed "s/ERROR/$ERROR/; s/REASON/$ErrorText/")${LinkDetailsText}$EmailEndText"                                                     # Ex: EmailBodyText='Hi&excl;%0A%0AYou have a problem with your backup: ANE4007E (&#8220;Error processing '\''#39;X'\'': access to the object is denied&#8221;).Here is a web page that descripes the error in more detail: https://fileadmin.cs.lth.se/intern/backup/ANE4007E.html%0A%0APlease contact us if you have any questions about this error.%0A%0Amvh,%0A/CS IT Staff'
                TableCell_1="<td width=\"13%\" align=\"right\">$(printf "%'d" $NumUserErrors)&nbsp;$MulSign&nbsp;</td>"             
                TableCell_2="<td width=\"22%\">$Node</td>"
                TableCell_3="<td width=\"35%\"><a href=\"mailto:$NodeEmail?&subject=Backup%20error%20$ERROR&body=${EmailBodyText/ /%20/}\">$NodeContact</a>$ErrorIcon</td>"
                TableCell_4="<td width=\"30%\">$NodeOS</td>"
                LocalLine="				<tr>${TableCell_1}${TableCell_2}${TableCell_3}${TableCell_4}</tr>"
                echo "$LocalLine" >> "$ErrorFileHTML"
            done
            echo "				</tbody>" >> "$ErrorFileHTML"
            echo "			</table>" >> "$ErrorFileHTML"
        done
    else
        echo "			<p><strong>No errors found in the domain “$DOMAIN”.</strong></p>" >> "$ErrorFileHTML"
    fi
    
    # Put the last lines in the fil     e:
    echo "    <p>&nbsp;</p>" >> "$ErrorFileHTML"
    echo "    <p align=\"center\"><a href=\"$MainURL\">Back to overview.</a></p>" >> "$ErrorFileHTML"
    echo "    <p>&nbsp;</p>" >> "$ErrorFileHTML"
    echo "	</section>" >> "$ErrorFileHTML"
    echo "	<section>" >> "$ErrorFileHTML"
    echo "    	<div class=\"flexbox-container\">" >> "$ErrorFileHTML"
    echo "			<div id=\"box-explanations\">" >> "$ErrorFileHTML"
    echo "	            <p><strong>Messages, return codes, and error codes:</strong></p>" >> "$ErrorFileHTML"
    echo "				<p><tt>ANE:</tt> <a href=\"https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=codes-ane-messages\">Client events logged to the server</a> <span class=\"glyphicon\">&#xe164;</span></p>" >> "$ErrorFileHTML"
    echo "				<p><tt>ANR:</tt> <a href=\"https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=codes-anr-messages\">Server common and platform-specific messages</a> <span class=\"glyphicon\">&#xe164;</span></p>" >> "$ErrorFileHTML"
    echo "				<p><tt>ANS:</tt> <a href=\"https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=SSEQVQ_8.1.16/client.msgs/r_client_messages.htm\">Client messages</a> <span class=\"glyphicon\">&#xe164;</span></p>" >> "$ErrorFileHTML"
    echo "		    </div>" >> "$ErrorFileHTML"
    echo "		</div>" >> "$ErrorFileHTML"
    echo "		$FOOTER_ROW" >> "$ErrorFileHTML"
    echo "  </section>" >> "$ErrorFileHTML"
    echo "	</div>" >> "$ErrorFileHTML"
    echo "</body>" >> "$ErrorFileHTML"
    echo "</html>" >> "$ErrorFileHTML"

    # Copy result if SCP=true
    if $SCP; then
        scp "$ErrorFileHTML" "${SCP_USER}@${SCP_HOST}:${SCP_DIR}${DOMAIN/_/\/}/errors.html" &>/dev/null
    fi

}

client_info() {
    ClientInfo="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LISt "query node $client f=d")"
    ClientVersion="$(echo "$ClientInfo" | grep -E "^\s*Client Version:" | cut -d: -f2 | sed 's/ Version //' | sed 's/, release /./' | sed 's/, level /./' | cut -d. -f1-3)"                   # Ex: ClientVersion='8.1.13'
    ContactName="$(echo "$ClientInfo" | grep -E "^\s*Contact:" | cut -d: -f2 | sed 's/^ *//')"                                                                                                # Ex: ContactName='Peter Moller'
    ContactEmail="$(echo "$ClientInfo" | grep -E "^\s*Email Address:" | cut -d: -f2 | sed 's/^ *//')"                                                                                         # Ex: ContactEmail='peter.moller@cs.lth.se'
    NodeRegisteredDate="$(echo "$ClientInfo" | grep -E "^\s*Registration Date/Time:" | cut -d: -f2- | sed 's/^ *//' | awk '{print $1}')"                                                      # Ex: NodeRegistered=2022-07-01
    # Ugly fix for getting US date format to ISO 8601 (MM/DD/YY -> YYYY-MM-DD). See https://en.wikipedia.org/wiki/ISO_8601
    if [ "$(echo "$NodeRegisteredDate" | cut -c3,6)" = "//" ]; then
        NodeRegisteredDate="20${NodeRegisteredDate:6:2}-${NodeRegisteredDate:0:2}-${NodeRegisteredDate:3:2}"
    fi
    NodeRegisteredBy="$(echo "$ClientInfo" | grep -E "^\s*Registering Administrator:" | cut -d: -f2- | sed 's/^ *//' | awk '{print $1}')"                                                     # Ex: NodeRegisteredBy=ADMIN
    PolicyDomain="$(echo "$ClientInfo" | grep -E "^\s*Policy Domain Name:" | cut -d: -f2 | sed 's/^ *//')"                                                                                    # Ex: PolicyDomain=PD_01
    CloptSet="$(echo "$ClientInfo" | grep -E "^\s*Optionset:" | cut -d: -f2 | sed 's/^ *//')"                                                                                                 # Ex: CloptSet=PD_01_OS_MACOS_2
    Schedule="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query schedule $PolicyDomain node=$client" 2>/dev/null | grep -Ei "^\s*Schedule Name:" | cut -d: -f2 | sed 's/^ //')"  # Ex: Schedule=DAILY_10
    ScheduleStart="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query schedule $PolicyDomain $Schedule f=d" | grep -E "^\s*Start Date/Time:" | awk '{print $NF}')"                # Ex: ScheduleStart=08:00:00
    ScheduleDuration="+ $(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query schedule $PolicyDomain $Schedule f=d" | grep -E "^\s*Duration:" | cut -d: -f2 | sed 's/^ *//')"        # Ex: ScheduleDuration='+ 10 Hour(s)'
    TransportMethod="$(echo "$ClientInfo" | grep -E "^\s*Transport Method:" | cut -d: -f2 | sed 's/^ *//')"                                                                                   # Ex: TransportMethod='TLS 1.3'
    ClientCanDeleteBackup="$(echo "$ClientInfo" | grep -E "^\s*Backup Delete Allowed\?:" | cut -d: -f2 | sed 's/^ *//')"                                                                      # Ex: ClientCanDeleteBackup=No
    ClientLastNetworkTemp="$(echo "$ClientInfo" | grep -Ei "^\s*TCP/IP Address:" | cut -d: -f2 | sed 's/^ //')"                                                                               # Ex: ClientLastNetworkTemp='10.7.58.184'
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
    ClientOS="$(echo "$ClientInfo" | grep -Ei "^\s*Client OS Name:" | cut -d: -f3 | sed 's/Microsoft //' | sed 's/ release//' | cut -d\( -f1)"
    # Ex: ClientOS='Macintosh' / 'Ubuntu 20.04.4 LTS' / 'Windows 10 Education' / 'Fedora release 36' / 'Debian GNU/Linux 10' / 'CentOS Linux 7.9.2009'
    # Get some more info about macOS:
    if [ "$ClientOS" = "Macintosh" ]; then
        OSver="$(echo "$ClientInfo" | grep -Ei "^\s*Client OS Level:" | cut -d: -f2)"
        ClientOS="macOS$OSver"
    fi
    ClientLastAccess="$(echo "$ClientInfo" | grep -Ei "^\s*Last Access Date/Time:" | cut -d: -f2-)"                                                                                           # Ex: ClientLastAccess='2018-11-01   11:39:06'
    ClientOccupancy="$(LANG=en_US dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LISt "query occup $client")"
    # Deal with clients who are using deduplication.
    # (If they are, the server does only present the 'Logical Space Occupied' number since it actually cannot determine the physical space occupied)
    if [ -z "$(echo "$ClientOccupancy" | grep "Physical Space Occupied" | cut -d: -f2 | grep -o '-')" ]; then
        OccupiedPhrase="Physical Space Occupied"
    else
        OccupiedPhrase="Logical Space Occupied"
    fi
    ClientTotalSpaceTemp="$(echo "$ClientOccupancy" | grep "$OccupiedPhrase" | cut -d: -f2 | sed 's/,//g' | tr '\n' '+' | sed 's/+$//')"                                                      # Ex: ClientTotalSpaceTemp=' 217155.02+ 5.20+ 1285542.38'
    ClientTotalSpaceUsedMB=$(echo "scale=0; $ClientTotalSpaceTemp" | bc | cut -d. -f1)                                                                                                        # Ex: ClientTotalSpaceUsedMB=1502702
    ClientTotalSpaceUsedGB=$(echo "scale=0; ( $ClientTotalSpaceTemp ) / 1024" | bc 2>/dev/null | cut -d. -f1)                                                                                 # Ex: ClientTotalSpaceUsedMB=1467
    ClientTotalNumfilesTemp="$(echo "$ClientOccupancy" | grep "Number of Files" | cut -d: -f2 | sed 's/,//g' | tr '\n' '+' | sed 's/+$//')"                                                   # ClientTotalNumfilesTemp=' 1194850+ 8+ 2442899'
    ClientTotalNumFiles=$(echo "scale=0; $ClientTotalNumfilesTemp" | bc | cut -d. -f1)                                                                                                        # Ex: ClientTotalNumFiles=1502702
    # Get the number of client file spaces on the server
    ClientNumFilespacesOnServer=$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LISt "query occupancy $client" | grep -cE "^\s*Filespace Name:")                                       # Ex: ClientNumFilespacesOnServer=2
}

backup_result() {
    # Number of files:
    # (note that some client use a unicode 'non breaking space', e280af, as thousands separator. This must be dealt with!)
    # (also, note that some machines will have more than one line of reporting. We only consider the last one)
    BackedupNumfiles="$(grep ANE4954I $ClientFile | sed 's/\xe2\x80\xaf/,/' | grep -Eo "Total number of objects backed up:\s*[0-9,]*" | awk '{print $NF}' | sed 's/,//g' | tail -1)"          # Ex: BackedupNumfiles='3483'
    TransferredVolume="$(grep ANE4961I $ClientFile | grep -Eo "Total number of bytes transferred:\s*[0-9,.]*\s[KMG]?B" | tail -1 | cut -d: -f2 | sed 's/\ *//' | tail -1)"                    # Ex: TransferredVolume='1,010.32 MB'
    BackeupElapsedtime="$(grep ANE4964I $ClientFile | grep -Eo "Elapsed processing time:\s*[0-9:]*" | tail -1 | awk '{print $NF}' | tail -1)"                                                 # Ex: BackedupElapsedtime='00:46:10'
    LastFinishDateTemp="$(echo "$AllConcludedBackups" | grep -E "ANR2507I|ANR2579E" | tail -1 | awk '{print $1}')"                                                                            # Ex: LastFinishDateTemp=2022-09-16
    if [ "$(echo "$LastFinishDateTemp" | cut -c3,6)" = "//" ]; then
        LastFinishDate="20${LastFinishDateTemp:6:2}-${LastFinishDateTemp:0:2}-${LastFinishDateTemp:3:2}"
        else
        LastFinishDate="$LastFinishDateTemp"
    fi
    LastFinishTime="$(echo "$AllConcludedBackups" | grep -E "ANR2507I|ANR2579E" | tail -1 | awk '{print $2}')"                                                                                # Ex: LastFinishTime=12:34:01
    # So, did it end successfully (ANR2507I)?
    if [ -n "$(grep ANR2507I $ClientFile)" ]; then
        BackupStatus="Successful"
    # Did it end, but unsuccessfully (ANR2579E)?
    elif [ -n "$(grep ANR2579E $ClientFile)" ]; then
        BackupStatus="Conflicted!!"
    else
        # OK, so there has been no backup today (successful or not). 
        # We need to get historical information (i.e. NOT look to ClientFile but rather AllConcludedBackups)
        BackupStatus=""
        # No backup the last day; we need to investiage!
        # Look for ANR2507I in the total history
        LastSuccessfulBackup="$(echo "$AllConcludedBackups" | grep -E "\b${client}\b" | grep ANR2507I | tail -1 | awk '{print $1" "$2}')"                                                     # Ex: LastSuccessfulBackup='08/28/2022 20:01:03'
        EpochtimeLastSuccessful=$(date -d "$LastSuccessfulBackup" +"%s")                                                                                                                      # Ex: EpochtimeLastSuccessful=1661709663
        LastSuccessfulNumDays=$(echo "$((NowEpoch - EpochtimeLastSuccessful)) / 81400" | bc)                                                                                                  # Ex: LastSuccessfulNumDays=11
        # The same for ANR2579E:
        LastUnsuccessfulBackup="$(echo "$AllConcludedBackups" | grep -E "\b${client}\b" | grep ANR2579E | tail -1 | awk '{print $1" "$2}')"                                                   # Ex: LastUnsuccessfulBackup='10/18/22 14:07:41'
        EpochtimeLastUnsuccessfulBackup=$(date -d "$LastUnsuccessfulBackup" +"%s")                                                                                                            # Ex: EpochtimeLastUnsuccessful=1666094861
        LastUnsuccessfulNumDays=$(echo "$((NowEpoch - EpochtimeLastUnsuccessfulBackup)) / 81400" | bc)                                                                                        # Ex: LastSuccessfulNumDays=1
        # If there is a successful backup in the total history, get when that was
        if [ -n "$LastSuccessfulBackup" ]; then
            if [ $LastSuccessfulNumDays -eq 0 ]; then
                BackupStatus="Successful"
            elif [ $LastSuccessfulNumDays -eq 1 ]; then
                BackupStatus="Yesterday"
            else
                BackupStatus="$LastSuccessfulNumDays days ago"
            fi
        elif [ -n "$LastUnsuccessfulBackup" ]; then
            # there was an unsuccessful backup - report it
            if [ $LastUnsuccessfulNumDays -eq 1 ]; then
                BackupStatus="Yesterday (conflicted)"
            else
                BackupStatus="$LastUnsuccessfulNumDays days ago (conflicted)"
            fi
        elif [ -z "$ClientTotalNumFiles" ] && [ -z "$ClientTotalSpaceUsedGB" ]; then
            BackupStatus="NEVER"
            ErrorMsg="Client \"$client\" has never had a backup"
        else
        # So there is no info about backup but still files on the server. 
            # There is no known backup, but there *are* files on the server, it's "complicated"
            BackupStatus=">${ActLogLength} days"
            #ErrorMsg="No backup in $ActLogLength days but files on server; "
            ErrorMsg="Last contact: $(echo "$ClientLastAccess" | awk '{print $1}'); "
            # Get the number of days since the last contact
            LastContactEpoch=$(date +%s -d "$ClientLastAccess")                   # Ex: LastContactEpoch='1541068746'
            DaysSinceLastContact=$(echo "scale=0; $((NowEpoch - LastContactEpoch)) / 86400" | bc -l)
            # Update 2022-10-23: I now know how to get the last date of backup: 
            # Do a 'query filespace $client f=d' and look for "Days Since Last Backup Completed:"
            # Note that it will be one day per filespace (file system)
            NumDaysSinceLastBackup="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LISt  "query filespace $client f=d" | grep -E "^\s*Days Since Last Backup Completed:" | cut -d: -f2 | sed 's/[, <]//g' | sort -u)"
            # Ex: NumDaysSinceLastBackup='1
            #     298
            #     339'
            LastBackupDate="$(dsmadmc -id="$ID" -password="$PASSWORD" -DISPLaymode=LISt  "query filespace $client f=d" | grep -E "^\s*Last Backup Completion Date/Time:" | cut -d: -f2 | awk '{print $1}' | sort -V | sort --field-separator='/' -k 3,3 -k 2,2 -k 1,1 | uniq)"
            # Ex: LastBackupDate='09/23/17
            #     01/05/20
            #     04/12/21
            #     10/17/22'
            # different way of doing this if we have one or more rows
            if [ $(echo "$NumDaysSinceLastBackup" | wc -l) -eq 1 ]; then
                BackupStatus="$NumDaysSinceLastBackup days ago"
                CriticalErrorMsg="CRITICAL: BACKUP IS NOT WORKING!!<br>Last complete backup was $LastBackupDate"
            else
                BackupStatus="$(echo "$NumDaysSinceLastBackup" | head -1) - $(echo "$NumDaysSinceLastBackup" | tail -1) days ago"
                CriticalErrorMsg="CRITICAL: BACKUP IS NOT WORKING!!<br>Last complete backup was between $(echo "$LastBackupDate" | head -1) and $(echo "$LastBackupDate" | tail -1)"
            fi
        fi
    fi
}

error_detection() {
    #ErrorMsg=""
    # First: see if there's no schedule associated with the node
    if [ -z "$Schedule" ]; then
        ErrorMsg+="--- NO SCHEDULE ASSOCIATED ---<br>"
    fi
    if [ -n "$(grep ANE4007E "$ClientFile")" ]; then
        NumErr=$(grep -c ANE4007E "$ClientFile")
        ErrorMsg+="$NumErr $MulSign <a href=\"https://fileadmin.cs.lth.se/intern/backup/ANE4007E.html\" target=\"_blank\" rel=\"noopener noreferrer\">ANE4007E</a> (access denied to object)<br>"
    fi
    if [ -n "$(grep ANR2579E "$ClientFile")" ]; then
        ErrorCodes="$(grep ANR2579E "$ClientFile" | grep -Eio "\(return code -?[0-9]*\)" | sed 's/(//' | sed 's/)//' | sort -u | tr '\n' ',' | sed 's/,c/, c/g' | sed 's/,$//')"
        NumErr=$(grep -c ANR2579E "$ClientFile")
        ErrorMsg+="$NumErr $MulSign <a href=\"https://fileadmin.cs.lth.se/intern/backup/ANR2579E.html\" target=\"_blank\" rel=\"noopener noreferrer\">ANR2579E</a> ($ErrorCodes)<br>"
    fi
    if [ -n "$(grep ANR0424W "$ClientFile")" ]; then
        NumErr=$(grep -c ANR0424W "$ClientFile")
        ErrorMsg+="$NumErr $MulSign <a href=\"https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=list-anr0010w#ANR0424W\" target=\"_blank\" rel=\"noopener noreferrer\">ANR0424W</a> (invalid password submitted)<br>"
    fi
    if [ -n "$(grep ANE4042E "$ClientFile")" ]; then
        NumErr=$(grep -c ANE4042E "$ClientFile")
        ErrorMsg+="$(printf "%'d" $NumErr) $MulSign <a href=\"https://fileadmin.cs.lth.se/intern/backup/ANE4042E.html\" target=\"_blank\" rel=\"noopener noreferrer\">ANE4042E</a> (unrecognized characters)<br>"
    fi
    if [ -n "$(grep ANE4081E "$ClientFile")" ]; then
        NumErr=$(grep -c ANE4081E "$ClientFile")
        ErrorMsg+="$(printf "%'d" $NumErr) $MulSign <a href=\"https://fileadmin.cs.lth.se/intern/backup/ANE4081E.html\" target=\"_blank\" rel=\"noopener noreferrer\">ANE4081E</a> (file space type is not supported)<br>"
    fi
    # Deal with excessive number of filespaces
    if [ $ClientNumFilespacesOnServer -gt 10 ]; then
        ErrorMsg+=">10 filespaces!; "
    fi
}

# Print the result
print_line() {
    # If we have a critical error message, display only that:
    if [ -n "$CriticalErrorMsg" ]; then
        ErrorMsg="$CriticalErrorMsg"
    fi
    # Set colors
    case "$BackupStatus" in
        "NEVER" ) TextColor=" style=\"color: red\"" ;;
        * ) TextColor="" ;;
    esac
    # Deal with a backup that kind of works but hasn't been run in a while
    if [ "${BackupStatus:0:2}" -gt 30 2>/dev/null ]; then
        TextColor=" style=\"color: orange\""
    fi
    # Deleted line - saved for precautions:
    # <td align=\"left\" $TextColor><a href=\"${OC_URL/BACKUPNODE/$client}\">$client</a></td>
    echo "        <tr class=\"clients\">
          <td align=\"left\" $TextColor><a href=\"${client,,}.html\">$client</a></td>
          <td align=\"right\"$TextColor>$(printf "%'d" $BackedupNumfiles)</td>
          <td align=\"right\"$TextColor>$TransferredVolume</td>
          <td align=\"left\" $TextColor>$BackeupElapsedtime</td>
          <td align=\"left\" $TextColor>${BackupStatus/ERROR/- NO BACKUP -}</td>
          <!--<td align=\"left\" $TextColor>$ClientLastNetwork</td>-->
          <td align=\"right\"$TextColor>$(printf "%'d" $ClientTotalNumFiles)</td>
          <td align=\"right\"$TextColor>$(printf "%'d" $ClientTotalSpaceUsedGB)</td>
          <!--<td align=\"right\"$TextColor>${ClientNumFilespacesOnServer:-0}</td>-->
          <td align=\"left\" $TextColor>$ClientVersion</td>
          <td align=\"left\" $TextColor>$ClientOS</td>
          <td align=\"left\" $TextColor>$(echo "$ErrorMsg" | sed 's/<br>$//')</td>
        </tr>" >> $ReportFileHTML
}

# Get the latest client versions
get_latest_client_versions() {
    LatestLinuxX86ClientVer="$(curl --silent https://fileadmin.cs.lth.se/intern/Backup-klienter/TSM/LinuxX86/.current_client_version | cut -d\. -f-3)"
    LatestLinuxX86_DEBClientVer="$(curl --silent https://fileadmin.cs.lth.se/intern/Backup-klienter/TSM/LinuxX86_DEB/.current_client_version | cut -d\. -f-3)"
    LatestMacClientVer="$(curl --silent https://fileadmin.cs.lth.se/intern/Backup-klienter/TSM/Mac/.current_client_version | cut -d\. -f-3)"
    LatestWindowsClientVer="$(curl --silent https://fileadmin.cs.lth.se/intern/Backup-klienter/TSM/Windows/.current_client_version | cut -d\. -f-3)"
}

create_one_client_report() {
    ReportFile="$OutDir/${client,,}.html"                                                                                                                                                     # Ex: ReportFile=/var/tmp/tsm/cs/clients/cs-petermac.html
    chmod 644 "$ReportFile"
    cat "$HTML_Template_one_client_Head"  | sed "s/CLIENT_NAME/$client/g" > "$ReportFile"
    ToolTipText_PolicyDomain="<div class=\"tooltip\"><i>Policy Domain:</i><span class=\"tooltiptext\">A “<a href=\"https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=glossary#gloss_P__x2154121\">policy domain</a>” is an organizational way to group backup clients that share common backup requirements</span></div>"
    ToolTipText_CloptSet="<div class=\"tooltip\"><i>Cloptset:</i><span class=\"tooltiptext\">A “cloptset” (client option set) is a set of rules, defined on the server, that determines what files and directories are included and <em>excluded</em> from the backup</span></div>"
    ToolTipText_Schedule="<div class=\"tooltip\"><i>Schedule:</i><span class=\"tooltiptext\">A “<a href=\"https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=glossary#gloss_C__x2210629\">schedule</a>” is a time window during which the server and the client, in collaboration and by using chance, determines a time for backup to be performed</span></div>"
    ToolTipText_BackupDelete="<div class=\"tooltip\"><i>Can delete backup:</i><span class=\"tooltiptext\">Says whether or not a client node can delete files from it’s own backup</span></div>"
    ConflictedText="<em>(A backup </em>has<em> been performed, but a <a href=\"https://www.ibm.com/docs/en/spectrum-protect/$ServerVersion?topic=list-anr0010w#ANR2579E\" target=\"_blank\" rel=\"noopener noreferrer\">ANR2579E</a> has occurred,<br>erroneously indicating that no backup has taken place)</em>"
    # Get more detail for macOS:
    if [ "$ClientOS" = "Macintosh" ]; then
        ClientOSLevel="$(echo "$ClientInfo" | grep -Ei "^\s*Client OS Level:" | cut -d: -f2 | sed 's/^\ //')"                                                                                 # Ex: ClientOSLevel='10.16.0'
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
    echo "        <tr><th colspan=\"2\">Information about the node</th></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Contact:</i></td><td align=\"left\">$ContactName</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Email address:</i></td><td align=\"left\">$ContactEmail</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Node registered by:</i></td><td align=\"left\">${NodeRegisteredBy:--unknown-} on ${NodeRegisteredDate:--unknown-}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\">$ToolTipText_PolicyDomain</td><td align=\"left\">${PolicyDomain:--unknown-}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\">$ToolTipText_CloptSet</td><td align=\"left\">${CloptSet:--unknown-}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\">$ToolTipText_Schedule</td><td align=\"left\">${Schedule:--unknown-} ($ScheduleStart ${ScheduleDuration,,})</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Transport Method:</i></td><td align=\"left\">${TransportMethod:-unknown}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Connected to Server:</i></td><td align=\"left\">${ServerName:--} (<a href=\"$SP_WikipediaURL\" $LinkReferer>Spectrum Protect</a> <a href=\"$SP_WhatsNewURL\" $LinkReferer>$ServerVersion</a>)</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\">$ToolTipText_BackupDelete</td><td align=\"left\">${ClientCanDeleteBackup}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Client version:</i></td><td align=\"left\">$ClientVersion</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Client OS:</i></td><td align=\"left\">$ClientOS</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Client last access:</i></td><td align=\"left\">${ClientLastAccess:-no info}</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Client last network:</i></td><td align=\"left\">${ClientLastNetwork:-no info}</td></tr>" >> $ReportFile
    # Fix the strange situation where a backup has taken place but Return code 12 says it hasn't
    if [ "$BackupStatus" = "Conflicted!!" ]; then
        BackupStatus="Conflicted!!<br>$ConflictedText"
    fi
    # Print information about the backup the specified time period:
    # Set colors
    case "$BackupStatus" in
        "NEVER" ) TextColor=" style=\"color: red\"" ;;
        * ) TextColor="" ;;
    esac
    # Deal with a backup that kind of works but hasn't been run in a while
    if [ "${BackupStatus:0:2}" -gt 30 2>/dev/null ]; then
        TextColor=" style=\"color: orange\""
    fi
    echo "        <tr><th colspan=\"2\">Information about backup today:</th></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Backup Status:</i></td><td align=\"left\"$TextColor>${BackupStatus//_/ }</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Nbr. files:</i></td><td align=\"left\"$TextColor>$(printf "%'d" $BackedupNumfiles)</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Bytes transferred:</i></td><td align=\"left\"$TextColor>$TransferredVolume</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Time elapsed:</i></td><td align=\"left\"$TextColor>$BackeupElapsedtime</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Backup concluded:</i></td><td align=\"left\"$TextColor>$LastFinishDate $LastFinishTime</td></tr>" >> $ReportFile
    echo "        <tr><td align=\"right\"><i>Errors encountered:</i></td><td align=\"left\"$TextColor>$(echo "$ErrorMsg" | sed 's/<br>$//')</td></tr>" >> $ReportFile
    echo "      </tbody>" >> $ReportFile
    echo "    </table>" >> $ReportFile
    echo "    <p>&nbsp;</p>" >> $ReportFile
    # Print info about the client on the server
    echo "    <table id=\"information\">" >> $ReportFile
    echo "      <thead>" >> $ReportFile
    echo "        <tr><th colspan=\"8\">Client usage of server resources:</th></tr>" >> $ReportFile
    echo "      </thead>" >> $ReportFile
    echo "      <tbody>" >> $ReportFile
    echo "        <tr><td><i>Filespace Name</i></td><td align=\"right\"><i>FSID</i></td><td><i>Type</i></td><td align=\"right\"><i>Nbr files</i></td><td align=\"right\"><i>Space Used [GB]</i></td><td align=\"right\"><i>Usage</i></td><td><i>Last backup</i></td><td><i>Days ago</i></td> </tr>" >> $ReportFile
    FSIDs="$(echo "$ClientOccupancy" | grep -E "^\s*FSID:" | cut -d: -f2 | tr '\n' ' ')"                                                                                                      # Ex: FSIDs=' 2  1 '
    for fsid in $FSIDs
    do
        FSName=""
        NbrFiles=0
        SpaceOccup=0
        OccupInfo="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query occupancy $client $fsid nametype=fsid")"
        FSInfo="$(dsmadmc -id=$ID -password=$PASSWORD -DISPLaymode=LISt "query filespace $client $fsid nametype=fsid f=d")"
        FSName="$(echo "$OccupInfo" | grep -E "^\s*Filespace Name:" | cut -d: -f2 | sed 's/^\ //')"
        FSType="$(echo "$FSInfo" | grep -E "^\s*Filespace Type:" | cut -d: -f2 | sed 's/^\ //')"                                                                                              # Ex: FSType=EXT4
        NbrFiles="$(echo "$OccupInfo" | grep -E "^\s*Number of Files:" | cut -d: -f2 | sed 's/^\ //' | cut -d\. -f1)"
        SpaceOccup="$(echo "$OccupInfo" | grep -E "Space Occupied" | cut -d: -f2 | grep -v "-" | tail -1 | sed 's/\xe2\x80\xaf/,/' | sed 's/\ //;s/,//g' | cut -d\. -f1)"                     # Ex: SpaceOccup=406869
        SpaceOccupGB=$(echo "scale=0; ( $SpaceOccup ) / 1024" | bc | cut -d. -f1)                                                                                                             # Ex: SpaceOccupGB=397
        # Detemine if we should present the usage as percent or per mille
        if [ $(printf %.1f $(echo "$SpaceOccupGB/$StgSizeTB" | bc -l) | cut -d\. -f1) -gt 10 ]; then 
            SpaceUsage="$(printf %.2f $(echo "$SpaceOccupGB/${StgSizeTB}0" | bc -l)) %"                                                                                                       # Ex: SpaceUsage='3.0 %'
        else
            SpaceUsage="$(printf %.2f $(echo "$SpaceOccupGB/$StgSizeTB" | bc -l)) ‰"                                                                                                          # Ex: SpaceUsage='1.5 ‰'
        fi
        LastBackupDate="$(echo "$FSInfo" | grep -E "Last Backup Completion Date/Time:" | cut -d: -f2 | awk '{print $1}')"                                                                     # Ex: LastBackupDate=11/28/22
        if [ "$(echo "$LastBackupDate" | cut -c3,6)" = "//" ]; then
            LastBackupDate="20${LastBackupDate:6:2}-${LastBackupDate:0:2}-${LastBackupDate:3:2}"
        fi
        LastBackupNumDays="$(echo "$FSInfo" | grep -E "Days Since Last Backup Completed:" | cut -d: -f2 | awk '{print $1}' | sed 's/[,<]//g')"                                                # Ex: LastBackupNumDays='<1'
        echo "        <tr><td align=\"left\"><code>${FSName:-no name}</code></td><td align=\"right\"><code>$fsid</code></td><td><code>${FSType:--??-}</code></td><td align=\"right\">${NbrFiles:-0}</td><td align=\"right\">$(printf "%'d" ${SpaceOccupGB:-0})</td><td align=\"right\">$SpaceUsage</td><td>${LastBackupDate}</td><td align=\"right\">${LastBackupNumDays:-0}</td></tr>" >> $ReportFile
    done
    case "$(echo "$ClientOS" | awk '{print $1}' | tr [:upper:] [:lower:])" in
        "macos"   ) LogFile="<code>/Library/Logs/tivoli/tsm</code>" ;;
        "windows" ) LogFile="<code>C:\TSM</code>\&nbsp;or\&nbsp;<code>C:\Program Files\Tivoli\baclient</code>" ;;
                * ) LogFile="<code>/var/log/tsm</code>\&nbsp;or\&nbsp;<code>/opt/tivoli/tsm/client/ba/bin</code>" ;;
    esac
    cat "$HTML_Template_one_client_End" | sed "s_LOGFILE_${LogFile}_; s|OC_URL|$OC_URL|; s/BACKUPNODE/${client,,}/; s|MAIN_URL|${MainURL}|; s|FOOTER_ROW|$FOOTER_ROW|; s/REPORT_DATE/$(date +%F)/; s/REPORT_TIME/$(date +%H:%M)/" >> $ReportFile

    # Copy result if SCP=true
    if $SCP; then
        scp "$ReportFile" "${SCP_USER}@${SCP_HOST}:${SCP_DIR}${DOMAIN/_/\/}/" &>/dev/null
    fi
}

#   _____   _   _  ______       _____  ______      ______   _   _   _   _   _____   _____   _____   _____   _   _   _____ 
#  |  ___| | \ | | |  _  \     |  _  | |  ___|     |  ___| | | | | | \ | | /  __ \ |_   _| |_   _| |  _  | | \ | | /  ___|
#  | |__   |  \| | | | | |     | | | | | |_        | |_    | | | | |  \| | | /  \/   | |     | |   | | | | |  \| | \ `--. 
#  |  __|  | . ` | | | | |     | | | | |  _|       |  _|   | | | | | . ` | | |       | |     | |   | | | | | . ` |  `--. \
#  | |___  | |\  | | |/ /      \ \_/ / | |         | |     | |_| | | |\  | | \__/\   | |    _| |_  \ \_/ / | |\  | /\__/ /
#  \____/  \_| \_/ |___/        \___/  \_|         \_|      \___/  \_| \_/  \____/   \_/    \___/   \___/  \_| \_/ \____/ 
#


# Get basic server info
server_info

# Get the activity log for today (saves time to do it only once)
# Do not include 'ANR2017I Administrator ADMIN issued command:' and a bunch of other stuff
# Make a variable with all error codes that are “irrelevant”:
StandardMessagesToIgnore="$(grep DISREGARD $SP_ErrorFile | cut -d\| -f1 | tr '\n' '|' | sed 's/|$//')"                                                                                        # Ex: StandardMessagesToIgnore='ANR0403I|ANR0405I|ANR0406I|...|ANR8601E'
dsmadmc -id="$ID" -password="$PASSWORD" -TABdelimited "query act begindate=today begintime=00:00:00 enddate=today endtime=now" | grep -Ev "$StandardMessagesToIgnore" > "$ActlogToday"
# Get all concluded executions (ANR2579E or ANR2507I) the last $ActLogLength. This will save a lot of time later on
AllConcludedBackups="$(dsmadmc -id="$ID" -password="$PASSWORD" -TABdelimited "query act begindate=today-$ActLogLength enddate=today" | grep -E "ANR2579E|ANR2507I")"

# Get the errors experienced today
errors_today

echo "To: $RECIPIENT" > $ReportFileHTML
echo "Subject: Backup report for ${DOMAIN%; }" >> $ReportFileHTML
echo "Content-Type: text/html" >> $ReportFileHTML
echo  >> $ReportFileHTML
if [ -n "$PUBLICATION_URL" ]; then
    echo "<a href=\"${PUBLICATION_URL}/${DOMAIN/_/\/}\">${PUBLICATION_URL}/${DOMAIN/_/\/}</a>" >> $ReportFileHTML
fi
echo  >> $ReportFileHTML

REPORT_H1_HEADER="Backup report for “${DOMAIN%; }”"
REPORT_DATE="$(date +%F)"
SERVER_STRING="running <a href=\"$SP_OverviewURL $LinkReferer\">Spectrum Protect</a> version <a href=\"$SP_WhatsNewURL $LinkReferer\">$ServerVersion</a>"
REPORT_HEAD="Backup report for ${Explanation% & } on server “$ServerName” ($SERVER_STRING) "
cat "$HTML_Template_Head" | sed "s/REPORT_H1_HEADER/$REPORT_H1_HEADER/; s;REPORT_DATE;$REPORT_DATE;; s;REPORT_HEAD;$REPORT_HEAD;; s/DOMAIN/$DOMAIN/g" >> $ReportFileHTML

# Loop through the list of clients
for client in $CLIENTS
do
    ClientFile="${OutDir}/${client,,}.out"
    ErrorMsg=""
    CriticalErrorMsg=""

    # Get the actlog for the client, but only consider the dollowing messages:
    # - ANE4954I:  Total number of objects backed up
    # - ANE4961I:  Total number of bytes transferred
    # - ANE4964I:  Elapsed processing time
    # - ANR2579E:  Schedule ... failed (return code 12)
    # - ANR2507I:  Schedule ... completed successfully
    # - ANE4007E:  Access to object is denied
    # - ANR0424W:  Session refused - invalid password
    # - ANE4042E:  Object contains unrecognized characters
    # - ANE4081E:  File space type not supported
    grep -Ei "\s$client[ \)]" "$ActlogToday" | grep -E "ANE4954I|ANE4961I|ANE4964I|ANR2579E|ANR2507I|ANE4007E|ANR0424W|ANE4042E|ANE4081E" > "$ClientFile"

    # Get client info (version, IP-address and such)
    client_info

    # Look for completion of backup
    backup_result

    # Look for errors:
    error_detection

    # Print the result
    print_line

    # Do the digging for each $client
    #"$ScriptDirName/inspect_one_client_html.sh" "$client" "${BackupStatus// /_}" &
    create_one_client_report

    rm $ClientFile
done

# Calculate elapsed time
Then=$(date +%s)
ElapsedTime=$(( Then - NowEpoch ))
REPORT_TIME="$(date +%H:%M)"
#REPORT_GENERATION_TIME="$((ElapsedTime%3600/60))m $((ElapsedTime%60))s"
REPORT_GENERATION_TIME="$((ElapsedTime%3600/60))m"

get_latest_client_versions

cat "$HTML_Template_End" | sed "s/REPORT_TIME/$REPORT_TIME/; s/REPORT_GENERATION_TIME/$REPORT_GENERATION_TIME/; s/LINUXX86VER/$LatestLinuxX86ClientVer/; s/LINUXX86DEBVER/$LatestLinuxX86_DEBClientVer/; s/MACOSVER/$LatestMacClientVer/; s/WINDOWSVER/$LatestWindowsClientVer/; s/STORAGE/$StorageText/; s|FOOTER_ROW|$FOOTER_ROW|" >> $ReportFileHTML
# Send an email report (but only if there is a $RECIPIENT
if [ -n "$RECIPIENT" ]; then
    # Used to be 'mailx' but that doesn't work anymore for some reason. So, using 'sendmail'
    #mailx -s "Backuprapport for ${DOMAIN%; }" "$RECIPIENT" < "$ReportFile"
    cat "$ReportFileHTML" | /sbin/sendmail -t
fi

# Copy result if SCP=true
if $SCP; then
    scp_file="$(mktemp)"
    # Trim the output file from the initial lines (that are only for email sending)
    sed -n '7,$p' "$ReportFileHTML" > "$scp_file"
    chmod 644 "$scp_file"
    scp "$scp_file" "${SCP_USER}@${SCP_HOST}:${SCP_DIR}${DOMAIN/_/\/}/index.html" &>/dev/null
    rm "$scp_file"
fi

rm "$ActlogToday"
