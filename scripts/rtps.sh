#!/bin/bash

# Note: since commit f8ccf312 of procps-ng, ps correctly displays processes with
# SCHED_DEADLINE as DLN, however at the time of writing (2017-08) there is no
# release of ps with this change, hence processes with deadline scheduling
# will be displayed with '#6' in their class column

# get_kthreadd_pid: returns the pid of the kthreadd process, responsible for the
# creation of all other kernel threads
get_kthreadd_pid(){
    ps -A | grep ' kthreadd$' | tr -s ' ' | cut -d' ' -f2 | head -n1
}

# get_pid_list: generates a pid list of all running processes
# $1: if set to 0 returns non-kernel threads only, otherwise returns all
get_pid_list(){
    local kern_pid
    if [ $1 -eq 0 ]; then
        kern_pid=$(get_kthreadd_pid)
        ps -p $kern_pid --ppid $kern_pid -N -o pid --no-header | tr -d ' ' | tr '\n' ' '
    else
        ps -A -o pid --no-header | tr -d ' ' | tr '\n' ' '
    fi
}

# filter_proc_by_class: filters the provided pid list by the scheduling class id
# $1: space-delimited list of pids to filter
# $2: scheduling class id, if '' doesn't filter
filter_proc_by_class(){
    local proc_class
    for pid in $1; do
        if [ -z "$2" ]; then
            echo $pid
        else
            proc_class=$(cat /proc/$pid/stat 2>/dev/null | cut -d' ' -f41)
            if [ "$proc_class" == "$2" ]; then
                echo $pid
            fi
        fi
    done
}

# print_pid_list: prints a newline-separated pid list with proper formatting
# $1: newline-separated list of pids
print_pid_list(){
    local pid_string
    if [ -n "$1" ]; then
        pid_string=$(tr '\n' ',' <<< """$1""" | sed 's/,$//g')
        ps -p $pid_string -o user,psr,pid,cmd,class,rtprio
    fi
}

# check_param: utility function to check if multiple scheduling filters
# are specified
# $1: new filter option to check
check_param(){
    if [ "$SCHED_F" != '' ]; then
        echo "Error: too many arguments: -$1"
        exit 1
    fi
}

# Main
K_THR=0
SCHED_F=''

while getopts ":kfrdbi" arg; do
    case $arg in
        k)
            K_THR=1
            ;;
        f)
            check_param 'f'
            SCHED_F=1
            ;;
        r)
            check_param 'r'
            SCHED_F=2
            ;;
        b)
            check_param 'b'
            SCHED_F=3
            ;;
        i)
            check_param 'i'
            SCHED_F=5
            ;;
        d)
            check_param 'd'
            SCHED_F=6
            ;;
    esac
done
ps_list=$(get_pid_list $K_THR)
filter_ps_list=$(filter_proc_by_class "$ps_list" $SCHED_F)
print_pid_list "$filter_ps_list"
