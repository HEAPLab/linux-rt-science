##Configuring the system

This page shows the steps to perform to prepare the system to run the real-time applications with
the lowest possible latency and intereference. You can also check [our script](./resources) to
check all these configurations in an automated way.

### Installing the PREEMPT_RT patch
The first step is to install a new kernel patched with the PREEMPT_RT patch and with the necessary
options enabled in the configuration. Each Linux distribution has its own procedure to install the
PREEMPT_RT patch (o, more generally, a patched kernel).

Some examples of distributions:
- Debian: it depends on the kernel version and architecture, the [debian packages website](https://packages.debian.org/search?searchon=all&keywords=PREEMPT_RT)
  is a good start
- Ubuntu: a package existed in the past, but in the last versions you need to compile it manually
- Arch Linux: the package from the [AUR repository](https://aur.archlinux.org/packages/linux-rt/) 

If you cannot find a package for your distribution or you need to set different configurations, you
have to compile del kernel manually. [This answer](https://stackoverflow.com/a/51709420/835146) is a
good small guide for Ubuntu (but can be used for any distribution).

### The kernel configuration parameters you should check
Besides the `CONFIG_PREEMPT_RT` (or `CONFIG_PREEMPT_RT_FULL` in some kernel versions) that is
necessary to enable the kernel patch, you should check or set these variables:
- `CONFIG_GENERIC_IRQ_MIGRATION=y`: this option enables the migration of interrupt routines to other
  cpus
- `CONFIG_IRQ_FORCED_THREADING=y`: it enables the threaded IRQs, to reduce the time spent in
  critical sections having interrupts disabled.
- `CONFIG_HZ_PERIODIC=n`: a periodic HZ clock may cause periodic spurious latencies
- `CONFIG_NO_HZ_IDLE=n`:  the HZ clock should be disabled when the cpu is idle
- `CONFIG_NO_HZ_FULL=n`:  (optional) it completely disables the HZ clock on the selected cpu even
  when tasks are running (for the CPU in the nohz_full at command line). This option should be
  careful set: disabling the HZ clock prevents the scheduler to preempt a task when its time slice
  is expired. A general suggestion is: keep this option disabled if you have a single task per-cpu,
  otherwise leave it on.
- `CONFIG_HZ`: According to the previous options, set the periodic timer interval (in Hz)

- `CONFIG_RCU_NOCB_CPU=n`: it enables the offloading of RCU callbacks to CPU running non-time
  critical workload.
- `CONFIG_RCU_NOCB_CPU_NONE=n` and `CONFIG_RCU_NOCB_CPU_ALL=y`: set all CPU as NOCB.
- `CONFIG_PREEMPT_RCU=y`: it enables the preemption of RCU routines.
    
- `CONFIG_HOTPLUG_CPU=y`: (optional) this is not stricly necessary for real-time, but it allows you to enable
   and disable cpu at run-time, which is usually very useful during experiments.
- `CONFIG_HIGH_RES_TIMERS=y`: (optional)  it enables the high resolution timers (if available in
  hardware). This is important when clock_gettime (and other time-related OS syscall like sleeps)
  are used.
- `CONFIG_PREEMPT_NOTIFIERS=y`: (optional) it enables a set of callback for the debugging of
  scheduler and latencies.

### Command line parameters
The bootloader provides to Linux a set of command line parameters. According to the previous
configurations, the interesting ones for real-time purposes are:
- `quiet`: this parameter disables most log messages from the kernel which may cause spurious latencies
- `isolcpus`: it isolates CPUs from the general scheduler. You should set here all the CPUs you
  would like to reserve for real-time applications. You have to leave at least 1 CPU out of this set
  (usually the boot CPU).
- `nohz_full`: if you have not set `CONFIG_NO_HZ_FULL`, you can set here the CPUs which have the HZ
  timer disabled. You have to leave at least 1 CPU out of this set (usually the boot CPU).
- `rcu_nocbs`: set the list of CPUs which have the RCU callbacks offloaded. Please note that this
  set must be a super-set of `nohz_full`. You have to leave at least 1 CPU out of this set
  (usually the boot CPU).

### Other configurations
- To reduce the latencies, if you do not need it, you can disable the watchdog and the NMI watchdog:
`# echo 0 > /proc/sys/kernel/watchdog`
`# echo 0 > /proc/sys/kernel/nmi_watchdog`

To make these actions permanent, you can edit the `/etc/sysctl.conf` file by adding:
`kernel.watchdog=0`
`kernel.nmi_watchdog=0`

- The `ftrace` kernel module is very useful kernel feature for debugging, but it can be the cause of
  very high latencies. To disable it, you can set the `/proc/sys/kernel/ftrace_enabled` to zero or
  edit the `/etc/sysctl.conf` file by adding:
`kernel.ftrace_enabled=0`

- Be sure that the kernel verbosity level is not too high (it should at least be < 4) by setting
  the relative sysfs file: `/proc/sys/kernel/printk` or the relative option in `/etc/sysctl.conf`

- Correctly configure the vmstat interval in `/proc/sys/vm/stat_interval`, which is the updater for
  the kernel statistics. Using an high value is suggested (> 60) to reduce the interferences.

### Scheduler and CGroups

### Governors

### Interrupts


