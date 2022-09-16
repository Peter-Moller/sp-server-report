# tsm-server-report
Shell scripts reporting about backup of TSM-clients.

There are two scripts:  
`inspect_one_client.sh`  
`inspect_all_clients.sh`

The first is intended for an interactive investigation of one specific client and the other for a mass-examination of a range of clients. In that case, the client list is an expected parameter to the script.

Both scripts are assumed to be run on the TSM server and requires a file, `tsm_secrets.env` (excluded from git), to be present in the directory of the repo. In that file, the `id` and `pwd` to be used by `dsmadmc` must be specified. It can also be a good place to put a `LANG` environment variable (I use `export LANG=sv_SE.UTF-8`).

####inspect\_one\_client.sh
It takes two parameters:

  1. Name of the client to look for
  2. How many days back to look for it. If no data is given, it starts from 00:00:00 the current day

First, the script looks for the client and warns if it isn’t found. After that, it digs for interesting information about the client and then for data from its history for the time given. 

The following is presented about the client:

  * Client name, timestamp from when the script is run, name of the TSM server and specification for time period (if any)
  * Contact Name
  * When the client was registered
  * What Policy Domain it belongs to
  * What Client Option Set (“cloptset”) is used
  * What Schedule and duration of that schedule

The following is presented about the history of the client for the given time period:

  * Client name (duh!)
  * Number of files, bytes transferred and time elapsed for the latest backup  
(based on `ANE4954I`, `ANE4961I` and `ANE4964I` respectively)
  * Status of the backup: if it was successful (`ANR2507I`)
  * Total number of files and Physical Space Occupied on the server (from `query occupancy CLIENTNAME`)
  * Version of the client software
  * Operating system on the client
  * Errors encoutered during the backup period
  * 

-----

Example:  
![examples of inspect_one_client](examples_of_inspect_one_client.jpg)
