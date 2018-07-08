#!/bin/ksh
#################################################################################################################
#
#           This script will help is automating NetWorker binary crash analysis across multiple
#           *NIX OS platforms. This will help the customers to collect all the information that
#           the EMC engineer is looking for. This will fasten the troubleshooting process.
# -------------------------------------------------------------------------------------------------------------
#
#          FILE:  nsrcorechk.sh
#         USAGE:  ./nsrcorechk.sh
#        AUTHOR:  STALIN STEPIN,
#       CONTACT: stalin.stepin@emc.com / stalin.stepin@outlook.com
#        GITHUB: https://github.com/stalinstepin/Project_NetWorker
#       COMPANY:  EMC
#       VERSION:  1.0
#       UPDATED:  03-24-2018
#
#    While this script performs a variety of tasks, there is still a lot of room for improvement.
#    Please report any bugs and/or suggestions to me.
#
#################################################################################################################

ULIMIT_CHECK=`ulimit -c`
SOLARIS=`uname -a`
LINUX=`uname -a`
AIX=`uname -a`
HPUX=`uname -a`
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
NOCOLOR="\033[0m"
TEMP_DIR=/nsr/logs/daemon-rendered.log


#----------------------------------------------------------------#
# Adding functions for OS check:                                 #
#----------------------------------------------------------------#

hpux_chk() {
    echo "$HPUX" | grep "HP-UX" > /dev/null
}

solaris_chk() {
    echo "$SOLARIS" | grep "SunOS" > /dev/null
}

linux_chk() {
    echo "$LINUX" | grep "Linux" > /dev/null;
}

aix_chk() {
    echo "$AIX" | grep "AIX" > /dev/null
}

#----------------------------------------------------------------#
# Checking if root user is running the shell script or not:      #
#----------------------------------------------------------------#

echo `whoami` | grep "root" > /dev/null
if [ `echo $?` = 1 ]
then
    printf "${RED}YOU ARE NOT RUNNING THE SCRIPT AS ROOT USER. KINDLY LOGIN AS ROOT USER TO RUN THE SCRIPT!${NOCOLOR}\n"
    exit 1
fi

#----------------------------------------------------------------#
# Reading User Input:                                            #
#----------------------------------------------------------------#

printf "\nEnter the SR number:\n"
read SR
`ls -t | head -1 | grep $SR`
if [ `echo $?` = 0 ]
then
    `rm -rf $SR`
else
    `mkdir -m 744 ./$SR`
fi
printf "Enter the process name that generated the core file.\n"
read nsr_process
printf "\n"

#----------------------------------------------------------------#
# Adding functions and variables for various check:              #
#----------------------------------------------------------------#

CORE_CHK=`(cd /nsr/cores/${nsr_process} && ls -t *.* | head -1) > /dev/null 2>&1`
CORE_HOLDER=`ls -t /nsr/cores/${nsr_process}/*.* | head -1`


gchk() {
    gchk=`which gcore > /dev/null 2>&1`
}

gdbchk() {
    gdbchk=`which gdb > /dev/null 2>&1`
}

pchk() {
    pchk=`which pstack > /dev/null 2>&1`
}

lgdbchk() {
    `linux_chk && gdbchk`
}

#------------------------------------------------------#
# Checking if ulimit has value unlimited:              #
#------------------------------------------------------#

if [ "$ULIMIT_CHECK" = 0 ]
then
    printf "\n${RED}# Current value of ulimit -c is: 0.\n# Use the below command to set 'ulimit' to unlimited which is recommended for proper generation of core files.\n Retry again after setting the value!!!${NOCOLOR}"
    printf "\n\n${GREEN}Command: ulimit -c unlimited${NOCOLOR}\n"
    `rm -rf $SR` > /dev/null
    exit 1
fi

#-------------------------------------------------------------------------------------------------------#
# Checking if strace, pstack and gcore is installed and if installed perform specific tasks.            #
#-------------------------------------------------------------------------------------------------------#

NSR_PID=`ps -ef | grep $nsr_process | grep -v grep | awk '{print $2}'`
gdbchk
if [ `echo $?` = 1 ]
then
    printf "${RED}# GDB is not installed. Install the package as its required for generating the core dump file for the process that is causing the issue.${NOCOLOR}"
    printf "\n${YELLOW}Continuing...${NOCOLOR}\n"
fi

pchk
if [ `echo $?` = 1 ]
then
    printf "${RED}\n# pstack is not installed. Install the package as its required for collecting stack trace of the PID of $nsr_process.${NOCOLOR}"
    printf "\n${YELLOW}Continuing...${NOCOLOR}\n"
else
    printf "${GREEN}\n# Running pstack on $nsr_process: "
    `pstack $NSR_PID > ${SR}/${nsr_process}-pstack.txt 2>&1`
    printf "Done.${NOCOLOR}"
fi

#-------------------------------------------------------------------------------------------------------#
# Running gcore and gdb on core file based on the core file existance.                                  #
#-------------------------------------------------------------------------------------------------------#

BINARY=`which $nsr_process`
COREFILE=`ls -t /nsr/cores/$nsr_process | head -1`

$CORE_CHK
if [ `echo $?` = 0 ]
then
    if [ `gdbchk; echo $?` = 0 ]
    then
        `cp $CORE_HOLDER $SR`
        printf "${GREEN}\n# Running GDB against the generated core file: "
        alias gdbbt="gdb -q -n -ex bt -batch"
        `gdbbt ${BINARY} /nsr/cores/${nsr_process}/${COREFILE} >> $SR/gdb_$nsr_process.log 2>&1`
        gdb --batch --quiet -ex "thread apply all bt full" -ex "quit" ${BINARY} /nsr/cores/${nsr_process}/${COREFILE} >> $SR/gdb_threadall_$nsr_process.log 2>&1
        gdb --batch --quiet -ex "bt full" -ex "quit" ${BINARY} /nsr/cores/${nsr_process}/${COREFILE} >> $SR/gdb_btfull_$nsr_process.log 2>&1
        gdb --batch --quiet -ex "info threads" -ex "quit" ${BINARY} /nsr/cores/${nsr_process}/${COREFILE} >> $SR/gdb_infothreads_$nsr_process.log 2>&1
        printf "Done.${NOCOLOR}\n"
    fi
else
    if [ `gchk && gdbchk; echo $?` = 0 ]
    then
        printf "\n${GREEN}# Generating a core file for $nsr_process: "
        `gcore -o $SR/core $NSR_PID > /dev/null 2>&1`
        printf "Done.${NOCOLOR}"
        printf "${GREEN}\n# Running GDB against the generated core file: "
        alias gdbbt="gdb -q -n -ex bt -batch"
        `gdbbt ${BINARY} /${SR}/core.* >> $SR/gdb_$nsr_process.log 2>&1`
        gdb --batch --quiet -ex "thread apply all bt full" -ex "quit" ${BINARY} /${SR}/core.* >> $SR/gdb_threadall_$nsr_process.log 2>&1
        gdb --batch --quiet -ex "bt full" -ex "quit" ${BINARY} /nsr/cores/${nsr_process}/${COREFILE} >> $SR/gdb_btfull_$nsr_process.log 2>&1
        gdb --batch --quiet -ex "info threads" -ex "quit" ${BINARY} /nsr/cores/${nsr_process}/${COREFILE} >> $SR/gdb_infothreads_$nsr_process.log 2>&1
        printf "Done.${NOCOLOR}"
    fi
fi


#------------------------------------------------------#
# Adding function for AIX:                             #
#------------------------------------------------------#

aix_func() {

    `nsr_render_log -S "last week" /nsr/logs/daemon.raw > $TEMP_DIR 2>&1`

# Collecting NetWorker Client Daemon logs:

`egrep 'signal 11|program not registered|Process exiting unexpectedly|segfault' $TEMP_DIR > /dev/null && aix_chk`
if [ `echo $?` = 0 ]
then
    printf "${GREEN}"
    printf "\n# Collecting NetWorker Client logs:"
    `cat $TEMP_DIR > ./$SR/nsr-crash.log`
    printf " Done.${NOCOLOR}"
else
    printf ""
fi

# Collecting Client System logs:

aix_chk
if [ `echo $?` = 0 ]
then
    printf "${GREEN}"
    printf "\n# Collecting System logs:"
    `errpt -a > ./$SR/AIX_errpt.log`
    printf " Done.${NOCOLOR}"
else
    printf ""
fi

# Running Snapcore on the latest core file generated:

aix_chk
if [ `echo $?` = 0 ]
then
    for file in `ls -t /nsr/cores/$nsr_process/*.* | head -1`; do
        printf "${GREEN}\n# Running Snapcore against $file: "
        /usr/sbin/snapcore $file `which $nsr_process` > /dev/null  2>&1
        cp `ls -t /tmp/snapcore/snapcore* | head -1` ./"$SR"
        printf "Done.${NOCOLOR}"
    done
else
    printf  ""
fi

# Compressing the collected log files and the Snapcore files:

aix_chk
if [ `echo $?` = 0 ]
then
    printf "${GREEN}\n# Archiving the files required for in-house analysis: "
    `tar -cvf "$SR".tar $SR` > /dev/null 2>&1
    printf "Done.${NOCOLOR}\n"
    printf "${GREEN}# Performing clean up: "
    `rm -rf $SR`
    printf "Done.${NOCOLOR}\n"
else
    printf ""
fi
}


#----------------------------------------------------------------------------------------#
# Checking if pkgcore is executable file or not. If not changing the file to executable: #
#----------------------------------------------------------------------------------------#

if [ -x "pkgcore_*.sh" ]
then
    printf ""
else
    chmod u+x *pkgcore_*.sh > /dev/null 2>&1
fi

#-----------------------------------------------------------------#
# Checking if the binary is "stripped" then perform the below     #
#-----------------------------------------------------------------#

file `which $nsr_process` | grep "not" > /dev/null
if [ `echo $?` = 1 ]
then
    printf "${RED}\n# You are using a 'stripped version' of $nsr_process. Kindly request for not-stripped binary from EMC Support for the below version:\n${NOCOLOR}"
    printf "${GREEN}\n"
    strings `which $nsr_process` | grep "@(#)" | grep "Release" | awk '{print $3}' | tee $SR/$nsr_process-version.txt
    printf "\n${NOCOLOR}${YELLOW}If you already have the not-stripped binary, rename the original one to $nsr_process.orig and place the not-stripped binary in that location. \nRestart NetWorker services for the changes to be applied.\n${NOCOLOR}"
    printf "\n${GREEN}# Running dependency check on 'stripped $nsr_process': "
    ldd `which $nsr_process` > $SR/ldd_stripped.txt  2>&1
    printf "Done.${NOCOLOR}"
    printf "${GREEN}\n# Archiving the files required for in-house analysis: "
    tar -cvf "$SR".tar `ls -t | head -1` > /dev/null 2>&1
    printf "Done."
    printf "${GREEN}\n# Performing clean up: `rm -rf $SR > /dev/null` Done.\n${NOCOLOR}"
    printf "${GREEN}# Kindly Upload: `ls -t | head -1` to the SR\n${NOCOLOR}\n"
    exit 1
fi

#------------------------------------------------------#
# Collecting Client Daemon logs from rendered version: #
#------------------------------------------------------#

`nsr_render_log -S "last week" /nsr/logs/daemon.raw > $TEMP_DIR 2>&1`


# Collecting Client Daemon logs - Crash check for Linux:
`grep 'signal 11\|program not registered\|Process exiting unexpectedly\|segfault' $TEMP_DIR > /dev/null && linux_chk`
if [ `echo $?` = 0 ]
then
    printf "${GREEN}"
    printf "# Collecting NetWorker Client logs:"
    `grep -A 20 -B 20 'signal 11\|program not registered\|Process exiting unexpectedly\|segfault' $TEMP_DIR > ./$SR/nsr-crash_linux.log`
    printf " Done.${NOCOLOR}\n"
else
    printf ""
fi

# Collecting Client Daemon logs - Crash check for Solaris
`egrep 'signal 11|program not registered|Process exiting unexpectedly|segfault' $TEMP_DIR > /dev/null && solaris_chk`
if [ `echo $?` = 0 ]
then
    printf "${GREEN}"
    printf "\n# Collecting NetWorker Client logs:"
    `/usr/sfw/bin/ggrep -A 20 -B 20 "signal 11" $TEMP_DIR >> ./$SR/nsr-crash_solaris.log`
    `/usr/sfw/bin/ggrep -A 20 -B 20 "program not registered" $TEMP_DIR >> ./$SR/nsr-crash_solaris.log`
    `/usr/sfw/bin/ggrep -A 20 -B 20 "Process exiting unexpectedly" $TEMP_DIR >> ./$SR/nsr-crash_solaris.log`
    `/usr/sfw/bin/ggrep -A 20 -B 20 "segfault" $TEMP_DIR >> ./$SR/nsr-crash_solaris.log`
    printf " Done.${NOCOLOR}\n"
else
    printf ""
fi

# Collecting Client Daemon logs - Crash check for HP-UX
`egrep 'signal 11|program not registered|Process exiting unexpectedly|segfault' $TEMP_DIR > /dev/null && hpux_chk`
if [ `echo $?` = 0 ]
then
    printf "${GREEN}"
    printf "\n# Collecting NetWorker Client logs:"
    `cat $TEMP_DIR > ./$SR/nsr-crash_hpux.log`
    printf " Done.${NOCOLOR}\n"
else
    printf ""
fi


#-------------------------------------------------#
# Collecting System Logs for analysing the crash: #
#-------------------------------------------------#

# System logs for Solaris:
solaris_chk
if [ `echo $?` = 0 ]
then
    printf "${GREEN}"
    printf "\n# Collecting System logs:"
    `/usr/sfw/bin/ggrep -A 20 -B 20 "signal 11" /var/adm/messages* >> ./$SR/Solaris_messages-crash.log`
    `/usr/sfw/bin/ggrep -A 20 -B 20 "program not registered" /var/adm/messages* >> ./$SR/Solaris_messages-crash.log`
    `/usr/sfw/bin/ggrep -A 20 -B 20 "Process exiting unexpectedly" /var/adm/messages* >> ./$SR/Solaris_messages-crash.log`
    `/usr/sfw/bin/ggrep -A 20 -B 20 "segfault" /var/adm/messages* >> ./$SR/Solaris_messages-crash.log`
    `dmesg | /usr/sfw/bin/ggrep -A 20 -B 20 "signal 11" >> ./$SR/Solaris_dmesg-crash.log`
    `dmesg | /usr/sfw/bin/ggrep -A 20 -B 20 "program not registered" >> ./$SR/Solaris_dmesg-crash.log`
    `dmesg | /usr/sfw/bin/ggrep -A 20 -B 20 "Process exiting unexpectedly" >> ./$SR/Solaris_dmesg-crash.log`
    `dmesg | /usr/sfw/bin/ggrep -A 20 -B 20 "segfault" >> ./$SR/Solaris_dmesg-crash.log`
    printf " Done.${NOCOLOR}\n"
else
    printf ""
fi

# System logs for Linux:

linux_chk
if [ `echo $?` = 0 ]
then
    printf "${GREEN}"
    printf "# Collecting System logs:"
    `grep -A 50 -B 50 'signal 11\|program not registered\|Process exiting unexpectedly\|segfault' /var/log/messages* > ./$SR/Linux_messages-crash.log`
    `dmesg | grep -A 20 -B 20 'signal 11\|program not registered\|Process exiting unexpectedly\|segfault' > ./$SR/Linux_dmesg-crash.log`
    printf " Done.${NOCOLOR}"
else
    printf ""
fi

# System logs for HP-UX:

hpux_chk
if [ `echo $?` = 0 ]
then
    printf "${GREEN}"
    printf "\n# Collecting System logs:"
    `cat /var/adm/syslog/syslog.log > ./$SR/HPUX_system-crash.log`
    `dmesg > ./$SR/HPUX_dmesg-crash.log`
    printf " Done.${NOCOLOR}\n"
else
    printf ""
fi


#---------------------------------------------------------------------------------------#
# Running pkgcore against the crash generated for "not stripped" binary if OS is Linux: #
#---------------------------------------------------------------------------------------#

linux_chk
if [ `echo $?` = 0 ]
then
    for file in `ls -t /nsr/cores/$nsr_process/*.* | head -1`; do
        printf "${GREEN}\n# Running pkgcore against $file: "
        ./pkgcore_Linux.sh pkgcore.output $file `which $nsr_process` > /dev/null  2>&1
        printf "Done.${NOCOLOR}"
    done
else
    printf  ""
fi

#-----------------------------------------------------------------------------------------#
# Running pkgcore against the crash generated for "not stripped" binary if OS is Solaris: #
#-----------------------------------------------------------------------------------------#

solaris_chk
if [ `echo $?` = 0 ]
then
    for file in `ls -t /nsr/cores/$nsr_process/*.* | head -1`; do
        printf "${GREEN}\n# Running pkgcore against $file: "
        ./pkgcore_SunOS.sh pkgcore.output $file `which $nsr_process` > /dev/null  2>&1
        printf "Done.${NOCOLOR}"
    done
else
    printf  ""
fi

#-------------------------------------------------------------------------------------------#
# Running pkgcore against the core file generated for "not stripped" binary if OS is HP-UX: #
#-------------------------------------------------------------------------------------------#

hpux_chk
if [ `echo $?` = 0 ]
then
    for file in `ls -t /nsr/cores/$nsr_process/*.* | head -1`; do # Better to add core.* because there could be any file with *.* and if its not a core file then we may get undesired output.
    printf "${GREEN}\n# Running pkgcore against $file: "
    ./pkgcore_HP-UX.sh pkgcore.output $file `which $nsr_process` > /dev/null  2>&1
    printf "Done.${NOCOLOR}"
done
else
    printf  ""
fi

#---------------------------------------------------#
# Compressing Files and later performing Clean up:  #
#---------------------------------------------------#
aix_chk
if [ `echo $?` = 0 ]
then
    aix_func
else
    printf "${GREEN}\n# Archiving the files required for in-house analysis: "
    tar -cvf "$SR".tar `ls -t | head -3` > /dev/null 2>&1
    printf "Done.${NOCOLOR}\n"
    printf "${GREEN}# Performing clean up: "
    `rm -rf ./pkgcore.output* $SR`
    printf "Done.${NOCOLOR}\n"
fi

#-------------------------------#
# Upload file to the SR:        #
#-------------------------------#

printf "${GREEN}# Kindly Upload: `ls -t | head -1` to the SR\n${NOCOLOR}\n"



