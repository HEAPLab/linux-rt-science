#!/bin/bash

################################################################################
#    Copyright 2021 Politecnico di Milano
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
################################################################################

# Utility Printing Functions
# They will all do nothing if the input string is empty/not present

# print_line: prints line with prepending result box
# $1: text to print, won't print line if empty
print_line (){
    if [ -n "$1" ]; then
        echo -e "[      ] $1"
    fi
}


# print_result: overwrites the previous line with the result
print_result(){
    if [ -n "$1" ]; then
        local answer
        answer=$(get_return_message $1)
        echo -e "\e[1A\r[ $answer"
    fi
}

# print_lineresult: combines the functionality of the previous
# two functions in one
# $1: the line to be printed
# $2: the result code to use (check get_return_message for codes)
print_lineresult(){
    if [ -n "$2" ]; then
        local answer
        answer=$(get_return_message $2)
    fi
    if [ -n "$1" ]; then
        echo -e "[ $answer ] $1"
    fi
}

# print_lineresult_error: prints result line and an error line
# $1: Message to be displayed in the result line
# $2: result code to use
# $3: error message to display
print_lineresult_error(){
    print_lineresult "$1" $2
    print_error "$3"
}

# Prints a line with ERROR prepended in red
print_error(){
    if [ -n "$1" ]; then
        echo -e "\e[91m\e[1mError\e[0m: $1"
    fi
}

print_notice(){
    if [ -n "$1" ]; then
        echo -e "\e[96m\e[1mNotice\e[0m: $1"
    fi
}

# get_return_message: gets the 4-char padded result message
# possible value are
#    0: OK
#    1: Caution
#    2: Warning
#    255: Not Present
get_return_message(){
    local answer
    if [ $1 -eq '0' ]; then
        #Everything went ok
        answer="\e[92m\e[1mGOOD\e[0m"
    elif [ $1 -eq '1' ]; then
        #We have to issue a warning
        answer="\e[93m\e[1mCAUT\e[0m"
    elif [ $1 -eq '2' ]; then
        #We have an Error
        answer="\e[91m\e[1mWARN\e[0m"
    elif [ $1 -eq '255' ]; then
        #The item was not present
        answer="\e[91m\e[1mNPRS\e[0m"
    fi
    echo $answer
}

# print_section_title: prints the section header
# $1: message to print
print_section_title(){
    echo -e "\e[1m~~~ $1 ~~~\e[0m"
}


# Utility Functions definitions

# check_variable_result: checks if the config variable is enabled
# if the variable is not present it is treated as not enabled
# $1: String to print
# $2: name of the config variable (prints nothing if empty)
# $3: result to print out if true
# $4: result to print out if false
# In case the variable is not found it will report as such
check_variable_result(){
    if [ -n "$1" ]; then
        local result_code
        local _rc
        if check_variable "$2"; then
            result_code=$3
            _rc=0
        else
            result_code=$4
            _rc=1
        fi
        print_lineresult "$1" $result_code
        return $_rc
    fi
}

# check_variable: returns 0 if the variable is set to y
# 1 otherwisei
# $1: name of the config variable
check_variable(){
    if [ -n "$1" ]; then
        config_val=$(get_variable_var "$1")
        if [ $? -eq 1 ]; then
            return 255
        fi
        if [ "$config_val" = "y" ]; then
            return 0
        else
            return 1
        fi
    else
        return 255
    fi
}

# get_variable_var: echoes the value for the specified kernel variable
# returns 1 if the variable is not present in the config
# $1: the name of the kernel variable
get_variable_var(){
    local config_line
    config_line=$(grep -e "$1=" <<< """$($config_cmd)""")
    if [ $? -eq 0 ]; then
        local config_params
        config_params=($( echo $config_line | tr '=' ' ' ))
        echo ${config_params[1]}
    else
        return 1
    fi
}

# get_config_cmd: generates the command needed to open the kernel config file
# (and removes all the comment line)
get_config_cmd(){
    if [ $(echo $config_path | grep "\w*.gz$") ]; then
        config_cmd="zcat $config_path"
    else
        config_cmd="cat $config_path"
    fi
}

# check_cmdline_result: checks if the specified string is in /proc/cmdline
# and prints the result
# $1: string to check
# $2: message to print
# $3: result if string is present
# $4: result if string is absent
check_cmdline_result(){
    if [ -n "$1" ]; then
        local rescode
        if check_cmdline "$1"; then
            rescode=$3
        else
            rescode=$4
        fi
        print_lineresult "$2" $rescode
    fi
}

# check_cmdline: checks if string is in /proc/cmdline
# returns 0 if the string is found, otherwise 1
# $1: string to check
check_cmdline(){
    if grep "$1" /proc/cmdline > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# get_cmdline_var: gets the value of the specified parameter in the commandline
# $1: variable to get
get_cmdline_var(){
    if [ -n "$1" ]; then
        echo $(cat /proc/cmdline | tr ' ' '\n' | grep "$1")
    fi
}

# parse_cr_list: Parses a comma-range list, echoes the resulting array
# $1: the string to parse
parse_cr_list(){
    local list
    local range
    local final_list
    IFS="," read -a list <<< """$1"""
    final_list=()
    for elem in "${list[@]}"; do
        if grep '-' <<< """$elem""" > /dev/null; then
            IFS="-" read -a range <<< """$elem"""
            range=( $(seq ${range[0]} ${range[1]}))
            final_list=( ${final_list[@]} ${range[@]} )
        else
            final_list=( ${final_list[@]} $elem )
        fi
    done
    echo ${final_list[@]}
}

# parse_bitmask_list: Parses a cpu bitmask and echoes the array
# $1: bitmask string
parse_bitmask_list(){
    if [ -n "$1" ]; then
        local fixed_bitmask=$(echo $1 | tr '[:lower:]' '[:upper:]')
        local bin_bitmask="$(echo "ibase=16; obase=2; $fixed_bitmask" | bc | \
                             sed 's/\(.\)/\1 /g;s/ $//' | tr ' ' '\n' | tac | \
                             tr '\n' ' ')"
        local int=0
        local ret_string=''
        for bit in $bin_bitmask; do
            if [ $bit -eq 1 ]; then
                ret_string="$ret_string $int"
            fi
            (( int++ ))
        done
        echo $ret_string
    fi
}

# get_file_value: gets the contents of a file and echoes them, returns 1 if
# the file was not found
# $1: filepath to check
get_file_value(){
    if [ -e "$1" ]; then
        cat "$1"
        return 0
    else
        return 1
    fi
}

# array_diff: returns an array with only the elements that are present
# in the first array
# $1: first array
# $2: second array
array_diff(){
    comm -23 <(echo "$1" | tr ' ' '\n' | sort) <(echo "$2" | tr ' ' '\n' | sort) | \
             tr '\n' ' ' | sed 's; $;;'
}

# array_same: returns an array with only the elements that are shared
# $1: first array
# $2: second array
array_same(){
    comm -12 <(echo "$1" | tr ' ' '\n' | sort) <(echo "$2" | tr ' ' '\n' | sort) | \
             tr '\n' ' ' | sed 's; $;;'
}


# Core function definitions

# find_config: returns the path to the kernel config file
# Will return an empty string should it fail
# It searches on the usual kernel config localtions and if it fails tries
# to check if the "config" module is present and ask the user if it can load it
find_config(){
    print_line "Checking config presence"
    if [ -e /proc/config.gz ]; then
        config_path="/proc/config.gz"
        print_result 0
    elif [ -e /boot/config ]; then
        config_path="/boot/config"
        print_result 0
    elif [ -e "/boot/config-$(uname -r)" ]; then
        config_path="/boot/config-$(uname -r)"
        print_result 0
    else
        if [ -n $(find /lib/modules/$(uname -r) -type f \( -name "config.ko" -o \
                -name "config.o" \) 2>/dev/null ) ]; then
            # If we arrive here there is a config.ko or config.o file in the modules directory
            print_result 1
            echo -ne "We have detected the \e[1mconfig\e[0m module, would you like to load it with sudo? [y/N/use (s)u instead] "
            read answer
            case "$answer" in
                [yY][eE][sS]|[yY])
                    sudo modprobe config 2>/dev/null
                    if [ "$?" -eq 0 ]; then
                        print_line "Rechecking config presence"
                        if [ -e /proca/config.gz ]; then
                            config_path="/proc/config.gz"
                            print_result 0
                        else
                            print_result 2
                        fi
                    fi
                    ;;
                su|s)
                    su -c "modprobe config" 2>/dev/null
                    if [ "$?" -eq 0 ]; then
                        print_line "Rechecking config presence"
                        if [ -e /proc/config.gz ]; then
                            config_path="/proc/config.gz"
                            print_result 0
                        else
                            print_result 2
                        fi
                    fi
                    ;;
            esac
        else
            print_result 2
        fi
    fi
}

# check_config_vars: checks the kernel config for proper settings
check_config_vars(){
    print_section_title "Checking for RT Preemption"
    check_variable_result "Checking if CONFIG_PREEMPT_RT is enabled" "CONFIG_PREEMPT_RT" 0 2
    check_variable_result "Checking if CONFIG_PREEMPT_RTB is disabled" "CONFIG_PREEMPT_RTB" 1 0
    check_variable_result "Checking if CONFIG_PREEMPT__LL is disabled" "CONFIG_PREEMPT__LL" 1 0
    check_variable_result "Checking if CONFIG_PREEMPT_VOLUNTARY is disabled" "CONFIG_PREEMPT_VOLUNTARY" 1 0
    check_variable_result "Checking if CONFIG_PREEMPT is disabled" "CONFIG_PREEMPT" 1 0
    check_variable_result "Checking if CONFIG_PREEMPT_NONE is disabled" "CONFIG_PREEMPT_NONE" 2 0
    if [ $? -eq 0 ]; then
        print_error "Non preemptible kernel"
    fi
    print_section_title "Checking Interrupts"
    check_variable_result "Checking if CONFIG_GENERIC_IRQ_MIGRATION is enabled" "CONFIG_GENERIC_IRQ_MIGRATION" 0 1
    check_variable_result "Checking if CONFIG_IRQ_FORCED_THREADING is enabled" "CONFIG_IRQ_FORCED_THREADING"  0 2
    print_section_title "Checking Tick Subsystem"
    check_variable_result "Checking if CONFIG_HZ_PERIODIC is disabled" "CONFIG_HZ_PERIODIC" 2 0
    check_variable_result "Checking if CONFIG_NO_HZ_IDLE is disabled" "CONFIG_HZ_IDLE" 1 0
    check_variable_result "Checking if CONFIG_NO_HZ_FULL is enabled" "CONFIG_HZ_FULL" 0 1
    check_variable "CONFIG_HZ_FULL_ALL"
    if [ $? -eq 0 ]; then
        print_notice "CONFIG_HZ_FULL_ALL is enabled"
    fi
    print_notice "CONFIG_HZ has value $(get_variable_var "CONFIG_HZ")"
    print_section_title "Checking RCU Subsystem"
    check_variable_result "Checking if CONFIG_RCU_NOCB_CPU is enabled" "CONFIG_RCU_NOCB_CPU" 0 2
    check_variable_result "Checking if CONFIG_RCU_NOCB_CPU_NONE is disabled" "CONFIG_RCU_NOCB_CPU_NONE" 2 0
#    check_variable_result "Checking if CONFIG_RCU_NOCB_CPU_ALL is enabled" "CONFIG_RCU_NOCB_CPU_ALL" 0 1 # Removed in 4.12
    check_variable_result "Checking if CONFIG_PREEMPT_RCU is enabled" "CONFIG_PREEMPT_RCU" 0 1
    print_section_title "Checking Other configs"
    check_variable_result "Checking if CONFIG_HOTPLUG_CPU is enabled" "CONFIG_HOTPLUG_CPU" 0 1
    check_variable_result "Checking if CONFIG_HIGH_RES_TIMERS is enabled" "CONFIG_HIGH_RES_TIMERS" 0 2
    check_variable_result "Checking if CONFIG_PREEMPT_NOTIFIERS is enabled" "CONFIG_PREEMPT_NOTIFIERS" 0 2
}

check_cmd_line(){
    print_section_title "Checking kernel command-line parameters"
    check_cmdline_result "quiet" "Checking for quiet boot" 0 1
    if check_cmdline "isolcpus"; then
        print_notice "$(get_cmdline_var "isolcpus")"
    else
        print_lineresult "isolcpu not specified in the kernel command parameters" 1
    fi
    if check_cmdline "nohz_full"; then
        print_notice "$(get_cmdline_var "nohz_full")"
    else
        if ! check_variable "CONFIG_NO_HZ_FULL"; then
            print_lineresult "nohz_full not present and NO_HZ_FULL disabled" 1
        fi
    fi
    if check_cmdline "rcu_nocbs"; then
        print_notice "$(get_cmdline_var "rcu_nocbs")"
    else
        if ! check_variable "CONFIG_RCU_NOCB_CPU_ALL"; then
            print_lineresult "rcu_nocbs not present and RCU_NOCB_CPU_ALL disabled" 1
        fi
    fi
}

# parse_isolcpus: parses the isolcpus list (through /sys/devices/system/cpu/isolated)
# and expands ranges. Saves the expanded array into $isolcpus_list.
parse_isolcpus(){
    isolcpus_list="$(parse_cr_list "$(cat /sys/devices/system/cpu/isolated)" )"
}

# check_governors: checks the currently enabled cpu governors for each cpu and
# reports if any of them don't have the performance governor
check_governors(){
    local nperf_norm nperf_isol nisolcpus_list allcpus_list
    nperf_norm=()
    nperf_isol=()
    allcpus_list=( $(parse_cr_list "$(cat /sys/devices/system/cpu/present)") )
    nisolcpus_list=( $(array_diff "${allcpus_list[*]}" "${isolcpus_list[*]}") )
    if [ ! -e '/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor' ]; then
        print_lineresult 'Cpu scaling information not present, check if cpufreq module is loaded' 1
        return 0
    fi
    for i in ${isolcpus_list[@]}; do
        if [ $(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor) != 'performance' ]; then
            nperf_isol=( ${nperf_isol[@]} $i )
        fi
    done
    for i in ${nisolcpus_list[@]}; do
        if [ $(cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor) != 'performance' ]; then
            nperf_norm=( ${nperf_norm[@]} $i )
        fi
    done
    if [ -n "$nperf_norm" ]; then
        echo -e "$(get_return_message 1): cpus $(echo "${nperf_norm[@]}" | tr ' ' ',') are not set with performance governor"
    fi
    if [ -n "$nperf_isol" ]; then
        echo -e "$(get_return_message 2): cpus $(echo "${nperf_isol[@]}" | tr ' ' ',') are not set with performance governor"
    fi
}

uname_check(){
    print_section_title "Checking if uname -a is proper"
    local check_msg
    check_msg="Checking PREEMPT in uname"
    grep 'PREEMPT' <<< """$(uname -a)""" > /dev/null
    if [ $? -eq 0 ]; then
        print_lineresult "$check_msg" 0
    else
        print_lineresult "$check_msg" 2
    fi
    check_msg="Checking 'PREEMPT_RT' in uname"
    grep 'PREEMPT_RT' <<< """$(uname -a)""" > /dev/null
    if [ $? -eq 0 ]; then
        print_lineresult "$check_msg" 0
    else
        print_lineresult "$check_msg" 1
    fi
}

procsys_check(){
    print_section_title "Checking Watchdog Presence"
    local f_val
    local check_msg
    check_msg="Checking if watchdog is disabled"
    f_val=$(get_file_value "/proc/sys/kernel/watchdog")
    if [ $? -eq 0 ] && [ $f_val = "1" ]; then
        print_lineresult "$check_msg" 1
        local watchdog_list
        local intersection_list
        watchdog_list=( $(parse_cr_list "$(cat /proc/sys/kernel/watchdog_cpumask)") )
        intersection_list=( $(array_same "${isolcpus_list[*]}" "${watchdog_list[*]}") )
        if [ -n "$intersection_list" ]; then
            print_lineresult "Watchdog is present on cpus $( echo "${intersection_list[*]}" | tr ' ' ',' )" 2
        fi
    else
        print_lineresult "$check_msg" 0
    fi


    print_section_title "Performing sysfs checks"
    check_msg="Checking if Ftrace is disabled"
    f_val=$(get_file_value "/proc/sys/kernel/ftrace_enabled")
    if [ $? -eq 0 ] && [ $f_val = "1" ]; then
        print_lineresult_error "$check_msg" 1 "Ftrace may introduce extra latencies"
    else
        print_lineresult "$check_msg" 0
    fi
    check_msg="Checking if NMI watchdog is disabled"
    f_val=$(get_file_value "/proc/sys/kernel/nmi_watchdog")
    if [ $? -eq 0 ] && [ $f_val = "1" ]; then
        print_lineresult_error "$check_msg" 1 "NMI watchdog is enabled and may introduce periodic extra latencies"
    else
        print_lineresult "$check_msg" 0
    fi
    check_msg="Checking printk level"
    f_val=( $(get_file_value "/proc/sys/kernel/printk") )
    if [ $? -eq 0 ] && [ "${f_val[1]}" -gt 4 ]; then
        print_lineresult_error "$check_msg" 1 "Print debugging level is too verbose"
    else
        print_lineresult "$check_msg" 0
    fi
    check_msg="Checking vmstat interval"
    f_val=$(get_file_value "/proc/sys/vm/stat_interval")
    if [ $? -eq 0 ] && [ "$f_val" -le 60 ]; then
        print_lineresult_error "$check_msg" 1 "vmstat interval seems too low"
    else
        print_lineresult "$check_msg" 0
    fi


    print_section_title "Checking RT timings"
    local period period_present
    local runtime runtime_present
    local percentage
    period=$(get_file_value "/proc/sys/kernel/sched_rt_period_us")
    period_present="$?"
    runtime=$(get_file_value "/proc/sys/kernel/sched_rt_runtime_us")
    runtime_present="$?"
    if [ $period_present -eq 0 ] && [ $runtime_present -eq 0 ]; then
        check_msg="Checking runtime share %"
        percentage=$(bc <<< """scale=2; $runtime/$period""")
        if [ $(bc <<< """$percentage<=50""") -eq 0 ]; then
            print_lineresult_error "$check_msg" 1 "Runtime allocated to real-time tasks seems too low"
        else
            print_lineresult "$check_msg" 0
        fi
    fi
    if [ $runtime_present -eq 0 ] && [ $runtime -eq 0 ]; then
        print_error "Real-time tasks have no time to execute"
    fi
    print_notice "RT timings value"
    if [ $period_present -eq 0 ]; then
        echo "sched_rt_period_us: $period"
    fi
    if [ $runtime_present -eq 0 ]; then
        echo "sched_rt_runtime_us: $runtime"
    fi
    f_val=$(get_file_value "/proc/sys/vm/sched_rr_timeslice_ms")
    if [ $? -eq 0 ]; then
        echo "sched_rr_timeslice_ms: $f_val"
    fi


    print_section_title "Checking cgroup presence"
    if grep '^cgroup' <(mount) > /dev/null; then
        print_notice "Mounted cgroups"
        grep '^cgroup' <(mount)
    fi

    print_section_title "Checking governor settings"
    if [ -d "/sys/devices/system/cpu/cpufreq" ]; then
        check_governors
    else
        print_notice "cpufreq not found, skipping governor checks"
    fi
    echo -e "$(get_return_message 1): you have $(lsmod | wc -l) modules loaded, you have to check the behaviour and latencies of them"


    print_section_title "Checking interrupt configuration"
    local irq_list irq_aff_list diff_list i_num
    irq_list=( $( find /proc/irq -mindepth 1 -maxdepth 1 -type d | tr '\n' ' ' ) )
    for fol in ${irq_list[@]}; do
        diff_list=()
        irq_aff_list=( $(parse_cr_list "$(cat "$fol/smp_affinity_list")") )
        diff_list=$( array_same "${isolcpus_list[*]}" "${irq_aff_list[*]}" )
        if [ -n "$diff_list" ]; then
            diff_list=( $(echo ${diff_list[*]}) )
            i_num=$(echo "$fol" | sed "s;/proc/irq/;;g")
            echo -e "$(get_return_message 1): isolated cpus $(echo "${diff_list[@]}" | tr ' ' ',') are registered for irq $i_num"
        fi
    done

    if [ -e "/proc/irq/default_smp_affinity" ]; then
        default_smp_list=( $( parse_bitmask_list "$(cat /proc/irq/default_smp_affinity)") )
        diff_list=$(array_same "${isolcpus_list[*]}" "${default_smp_list[*]}")
        if [ -n "$diff_list" ]; then
            echo -e "$(get_return_message 2): isolated cpus $(echo "${diff_list[@]}" | tr ' ' ',') are in default_smp_affinity"
        fi
    fi

    local wk_list=( $( find /sys/devices/virtual/workqueue -mindepth 1 -maxdepth 1 -type d | tr '\n' ' ' ) )
    for fol in ${wk_list[@]}; do
        if [ -e "$fol/cpumask" ]; then
            diff_list=()
            wk_aff_list=( $(parse_bitmask_list "$(cat "$fol/cpumask")") )
            diff_list=$( array_same "${isolcpus_list[*]}" "${wk_aff_list[*]}" )
            if [ -n "$diff_list" ]; then
                diff_list=( $(echo ${diff_list[*]}) )
                wk=$(echo "$fol" | sed "s;/sys/devices/virtual/workqueue/;;g")
                echo -e "$(get_return_message 2): isolated cpus $(echo "${diff_list[@]}" | tr ' ' ',') are registered for workqueue $wk"
            fi
        fi
    done
}

welcome(){
	echo -e "\e[1m~~~~~~~~~~~~~~~~~~~~~~~~~~~~\e[0m"
	echo -e "\e[1m~~~~    RTSysChecker     ~~~\e[0m"
	echo -e "\e[1m~~~~~~~~~~~~~~~~~~~~~~~~~~~~\e[0m"
	echo ""
	KERNEL_VERSION=`uname -r | cut -d'-' -f1,1 | cut -d'.' -f1,2`
	if [ "$KERNEL_VERSION" != "5.10" ]; then
		echo "WARNING: This script has been tested on kernel 5.10. Your kernel version appears to be $KERNEL_VERSION."
		echo "Please be aware that the results may be erroneous."
		echo "Press any key to continue..."
		read
	fi
}

# Main

welcome
find_config

if [ -n "$config_path" ]; then
    echo "Using config from $config_path"
    get_config_cmd
    check_config_vars
else
    echo "config not found, skipping kernel compilation flags checks"
fi
check_cmd_line
parse_isolcpus
uname_check
procsys_check
