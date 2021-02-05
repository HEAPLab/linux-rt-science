#!/bin/bash

# read_proccgroup: prints out cgroup information given a pid
# $1: the pid to print
read_proccgroup(){
    local cpath
    local line
    local cont
    for line in $(tac "/proc/$1/cgroup"); do
        cpath=$(echo "$line" | cut -d':' -f3)
        for cont in $(cut -d':' -f2 <<< """$line""" | tr ',' ' '); do
            cont=$(echo $cont | cut -d'=' -f2)
            printf '%s: %s\n' $cont $(get_cgroup_path "$cont" "$cpath")
        done
    done
}

# get_cgroup_path: returns the absolute cgroup folder path
# $1: controller name
# $2: path read from a line in /proc/[pid]/cgroup
get_cgroup_path(){
    echo "/sys/fs/cgroup/$1/$2" | sed 's;/\+;/;g' | sed 's;/$;;g'
}

# translate_sched_class: converts scheduling class id to a human-readable name
# $1: id of the scheduling class
translate_sched_class(){
    if [ -n "$1" ]; then
        case "$1" in
            0)
                echo "CFS";;
            1)
                echo "FIFO";;
            2)
                echo "Round-Robin";;
            3)
                echo "Batch";;
            5)
                echo "Idle";;
            6)
                echo "Deadline";;
            *)
                echo "Unknown";;
        esac
    fi
}


# print_bold: prints the string in bold
# $1: string to print
print_desc(){
    printf '\033[1m%-25s\033[0m' "$1"
}


# print_cgroups: prints the cgroup information given a pid
# $1: pid to use
print_cgroups(){
    local mounted_cgroups
    local first_line=0
    if [ "$(wc -l "/proc/$1/cgroup" 2>/dev/null | cut -d' ' -f1)" -gt 0 ]; then
        mounted_cgroups=$(read_proccgroup "$1")
        while read line; do
            if [ $first_line -eq 0 ]; then
                print_desc 'Cgroups:'
                echo "$line"
                first_line=1
            else
                printf "%s" "$(seq -s' ' 26 | tr -d '[:digit:]')"
                echo "$line"
            fi
        done < <(echo "$mounted_cgroups")
    fi
}

# print_quotas: prints quotas given a single pid
# $1: pid of the program
print_quotas(){

    if [ -e "/proc/$1/cgroup" ]; then
        local cgroup_path=$(grep -e ',cpu:' -e ',cpu,' -e ':cpu,' "/proc/$1/cgroup" | cut -d':' -f3)
        cgroup_path=$(get_cgroup_path "$cgroup_path")
        print_desc 'CFS Quota:'
        if [ -e "$cgroup_path/cpu/cpu.cfs_quota_us" ]; then
            printf '%s/%s\n' "$(cat "$cgroup_path/cpu/cpu.cfs_quota_us")" \
                             "$(cat "$cgroup_path/cpu/cpu.cfs_period_us")"
        else
            echo 'N/A'
        fi
        if [ -e "$cgroup_path/cpu.rt_runtime_us" ]; then
            print_desc 'RT Quota:'
            printf '%s/%s\n' "$(cat "$cgroup_path/cpu/cpu.rt_runtime_us")" \
                             "$(cat "$cgroup_path/cpu/cpu.rt_period_us")"
        else
            print_desc 'RT Quota:'
            printf '%s/%s\n' "$(cat '/proc/sys/kernel/sched_rt_runtime_us')" \
                             "$(cat '/proc/sys/kernel/sched_rt_period_us')"
        fi
    else
        print_desc 'RT Quota:'
        printf '%s/%s\n' "$(cat '/proc/sys/kernel/sched_rt_runtime_us')" \
                         "$(cat '/proc/sys/kernel/sched_rt_period_us')"
    fi
}

# print_description: prints the program description given a single pid
# $1: pid of the application
print_description(){
    if [ -n "$1" ]; then
        print_desc "Command line:"
        cat "/proc/$1/cmdline"
        echo ''
        print_desc "PID:"
        echo "$1"
        print_desc "User:"
        ps -p "$1" -o user --no-header
        print_desc "State:"
        grep '^State' "/proc/$1/status" | cut -f2-
        print_desc "Scheduling Policy:"
        translate_sched_class $(cut -d' ' -f41 "/proc/$1/stat")
        print_desc "Scheduling Priority:"
        cut -d' ' -f18 "/proc/$1/stat"
        print_cgroups "$1"
        print_desc "CPUs allowed:"
        grep '^Cpus_allowed_list' "/proc/$1/status" | cut -f2
        print_desc "MEMs allowed:"
        grep '^Mems_allowed_list' "/proc/$1/status" | cut -f2
        print_quotas "$1"
        print_desc "Nr. Context switches:"
        printf '%d (%d voluntary, %d involuntary)\n' $(grep '_switches' "/proc/$1/sched" | tr -d ' ' | cut -d':' -f2 | tr '\n' ' ')
        print_desc "Total Memory:"
        mem_size=$(grep '^VmSize' "/proc/$1/status")
        if [ -n "$mem_size" ]; then
            echo "$mem_size" | cut -f2 | sed 's/^ \+//g'
        else
            echo 'N/A'
        fi
        print_desc "Locked Memory:"
        lock_mem_size=$(grep '^VmLck' "/proc/$1/status")
        if [ -n "$lock_mem_size" ]; then
            echo "$lock_mem_size" | cut -f2 | sed 's/^ \+//g'
        else
            echo 'N/A'
        fi
    fi
}

# Main

while getopts ':p:' arg; do
    case $arg in
        p)
            pid_list="$(echo "$OPTARG" | tr ',' ' ')";;
    esac
done

if [ -z "$pid_list" ]; then
    pid_list="$(pidof $1)"
fi

first_entry=0

for pid in $pid_list; do
    if [ $first_entry -eq 0 ]; then
        first_entry=1
    else
        seq -s'-' 51 | tr -d '[:digit:]'
    fi
    print_description "$pid"
done
