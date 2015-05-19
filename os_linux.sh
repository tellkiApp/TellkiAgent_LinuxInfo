##################################################################################################################
## This script was developed by Guberni and is part of Tellki monitoring solution                     		 	##
##                                                                                                      	 	##
## December, 2014                     	                                                                	 	##
##                                                                                                      	 	##
## Version 1.0                                                                                          	 	##
##																									    	 	##
## DESCRIPTION: Collect server information (operating system, file systems, RAM, services, ...) 				##
##																											 	##
## SYNTAX: ./os_linux.sh             														 					##
##																											 	##
## EXAMPLE: ./os_linux.sh          														    	 				##
##																											 	##
##                                      ############                                                    	 	##
##                                      ## README ##                                                    	 	##
##                                      ############                                                    	 	##
##																											 	##
## This script is used combined with runremote_Infos.sh script, but you can use as standalone. 			    	##
##																											 	##
## runremote:Infos.sh - executes input script locally or at a remove server, depending on the LOCAL parameter.	##
##																											 	##
## SYNTAX: sh "runremote_Infos.sh" <HOST> <INFO_UUID> <USER_NAME> <PASS_WORD> <TEMP_DIR> <SSH_KEY> <LOCAL> 	 	##
##																											 	##
## EXAMPLE: (LOCAL)  sh "runremote_Infos.sh" "os_linux.sh" "192.168.1.1" "1" "" "" "" "" "1"              		##
## 			(REMOTE) sh "runremote_Infos.sh" "os_linux.sh" "192.168.1.1" "1" "user" "pass" "/tmp" "null" "0"  	##
##																											 	##
## HOST - hostname or ip address where script will be executed.                                         	 	##
## INFO_UUID - (internal): only used by tellki default monitors.       	 										##
## USER_NAME - user name required to connect to remote host. Empty ("") for local monitoring.           	 	##
## PASS_WORD - password required to connect to remote host. Empty ("") for local monitoring.            	 	##
## TEMP_DIR - (remote monitoring only): directory on remote host to copy scripts before being executed.		 	##
## SSH_KEY - private ssh key to connect to remote host. Empty ("null") if password is used.                 	##
## LOCAL - 1: local monitoring / 0: remote monitoring                                                   	 	##
##################################################################################################################

# timezone
TS=`date -u "+%Y-%m-%dT%H:%M:%SZ"`

#Host Build
host_build=`cat /etc/issue 2>/dev/null| head -1 | awk -F'\' '{print $1}'`

#hostname
host_name=`uname -n | awk -F'.' '{print $1}'`

#host_architecture
host_architecture=`uname -i`

#host_boot_time
host_boot_time=`who -b | sed 's/system boot//g' | sed 's/  //g'`

#host dns name
host_dns_name=`dnsdomainname 2>/dev/null`

#host ram
host_ram=`cat /proc/meminfo 2>/dev/null | grep MemTotal | awk '{print int($2/1024)}'`

#host manufacturer 
host_manufacturer=`dmidecode -s system-manufacturer 2>/dev/null`

#host model
host_model=`dmidecode -s system-product-name 2>/dev/null`

#host OS
host_os=`lsb_release -d 2>/dev/null | awk -F':' '{print $NF}'|sed 's/\t//g'`
if [ "$host_os" = "Fedora" ]
then 
host_os=`cat /etc/fedora-release`
fi
# if lsd_release is not installed
if [ "$host_os" = "" ]
then
host_os=`cat /etc/*release* | grep PRETTY_NAME | awk -F"=" '{print $2}' | awk -F"\"" '{print $2}'`
fi
#host os version and codename
host_os_codename=`lsb_release -c 2> /dev/null | awk -F':' '{print $NF}'|sed 's/\t//g'`
host_os_release=`lsb_release -r 2> /dev/null |awk -F':' '{print $NF}'|sed 's/\t//g'`

# if lsd_release is not installed
if [ "$host_os_release" = "" ]
then
host_os_release=`cat /etc/*release* | grep VERSION_ID | awk -F"=" '{print $2}' | awk -F"\"" '{print $2}'`
host_os_codename=`cat /etc/*release* | grep CODENAME | awk -F"=" '{print $2}'` 
fi


#host partitions
host_partitions=""
        for i in `cat /etc/mtab 2>/dev/null | grep -v "#" | grep -E " ext| ntfs| nfs| vfat| fat" | awk '{print $2}'`
        do
                fs_type=`cat /etc/mtab | grep -v "#"|awk '{print $2,$3}'| grep -E " ext| ntfs| nfs| vfat| fat" | grep -E "^$i " | awk '{print $2}'`
                mount_device=` cat /etc/mtab | grep -v "#"|awk '{print $1,$2,$3}' | grep -E " ext| ntfs| nfs| vfat| fat" | awk '{print $1,$2}' | grep -E " $i$" | awk '{print $1}'`
                size=`df -k | grep "%" | grep -w "$i$" | awk '{print int($(NF-4))}'|head -1`
                host_partitions="$host_partitions,{$i;$fs_type;$size;$mount_device}"
        done

host_partitions_fs=`echo $host_partitions | sed 's/^,//g'`

#host cpu
host_cpu_model=`cat /proc/cpuinfo | grep "model name" | sed 's/\s\s//g'| awk -F':' '{print $NF}' | sort -u`
cpu_num=`cat /proc/cpuinfo | grep "model name" | sed 's/\s\s//g'| awk -F':' '{print $NF}' | wc -l`
host_cpu="{$host_cpu_model;$cpu_num}"

#host network
host_net=""
host_ip=""
for x in `ifconfig 2>/dev/null | grep '^[a-Z]' |grep -v "lo"| awk '{print $1}'`
do
 net_type=`ifconfig | grep $x |grep encap|awk -F':' '{print $2}' | awk '{print $1}'`
 net_ip=`ifconfig $x | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $NF}'`
 net_mac=`ifconfig | grep $x |grep enc | awk '{print $NF}'`
 host_net="$host_net,{$x;$net_type;$net_mac;$net_ip}"
 host_ip="$net_ip"
done

host_network=`echo $host_net | sed 's/^,//g'`

#host servicos
servicos=""

if [ `find /bin /sbin -name chkconfig | wc -l` != 0 ]
then

for i in `chkconfig --list 2>/dev/null| grep  3:on | awk '{print $1}'`
do
	servicos="$servicos$i,"
done

for j in `chkconfig --list 2>/dev/null | grep  on | grep ": "| awk '{print $1}' | sed 's/://g'`
do
        servicos="$servicos$j,"
done

else

for i in `initctl list | grep start | grep process | grep -v tty |awk '{print $1}' | sort -u`
do
        servicos="$servicos$i,"
done

fi

os_temp=`cat /etc/issue 2>/dev/null| head -1 | awk -F' ' '{print $1}'`
if [ "$os_temp" = "Fedora" ]
then
host_os=$os_temp
host_os_release=`cat /etc/issue 2>/dev/null| head -1 | awk -F' ' '{print $3}'`
host_os_codename=`cat /etc/issue 2>/dev/null| head -1 | awk -F'(' '{print $2}' | awk -F ')' '{print $1}'`
fi

host_servicos=`echo $servicos| sed 's/,$//g'`

Output="$host_build||$host_name||$host_architecture||$host_boot_time||$host_dns_name||$host_ram||$host_manufacturer||$host_model||$host_os||$host_os_release||$host_os_codename||$host_partitions_fs||$host_cpu||$host_network||$host_servicos||$host_ip"

if [ "$Output" = "" ]
then
	#Unable to collect metrics
	exit 8
else	
	echo "$TS||1||$host_build||$host_name||$host_architecture||$host_boot_time||$host_dns_name||$host_ram||$host_manufacturer||$host_model||$host_os||$host_os_release||$host_os_codename||$host_partitions_fs||$host_cpu||$host_network||$host_servicos||$host_ip"
fi
