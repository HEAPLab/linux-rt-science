## Configuring the system

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
- IRQ-related
  - `CONFIG_GENERIC_IRQ_MIGRATION=y`: this option enables the migration of interrupt routines to other
    cpus
  - `CONFIG_IRQ_FORCED_THREADING=y`: it enables the threaded IRQs, to reduce the time spent in
  critical sections having interrupts disabled.
- Timers
  - `CONFIG_HZ_PERIODIC=n`: a periodic HZ clock may cause periodic spurious latencies
  - `CONFIG_NO_HZ_IDLE=y/n`: the HZ clock should be disabled when the cpu is idle, unless you select
    the next option:
  - `CONFIG_NO_HZ_FULL=y/n`: it completely disables the HZ clock on the selected cpu even
    when tasks are running (for the CPU in the nohz_full at command line). This option should be
    careful set: disabling the HZ clock prevents the scheduler to preempt a task when its time slice
    is expired. A general suggestion is: keep this option disabled if you have a single task per-cpu,
    otherwise leave it on.
  - `CONFIG_HZ`: According to the previous options, set the periodic timer interval (in Hz)
- RCU subsystem
  - `CONFIG_RCU_NOCB_CPU=n`: it enables the offloading of RCU callbacks to CPU running non-time
    critical workload.
  - `CONFIG_RCU_NOCB_CPU_NONE=n` and `CONFIG_RCU_NOCB_CPU_ALL=y`: set all CPU as NOCB. Note: the
    `CONFIG_RCU_NOCB_CPU_ALL` option has been removed since kernel version 4.12, for newer kernel is
    not necessarily to set it, but you have to set the kernel boot parameter (see later)
  - `CONFIG_PREEMPT_RCU=y`: it enables the preemption of RCU routines.
- Other options
  - `CONFIG_HOTPLUG_CPU=y`: (optional) this is not stricly necessary for real-time, but it allows you to enable
    and disable cpu at run-time, which is usually very useful during experiments.
  - `CONFIG_HIGH_RES_TIMERS=y`: (optional)  it enables the high resolution timers (if available in
    hardware). This is important when clock_gettime (and other time-related OS syscall like sleeps)
    are used.
  - `CONFIG_PREEMPT_NOTIFIERS=y`: (optional) it enables a set of callback for the debugging of
    scheduler and latencies.

### Command line boot parameters
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
```
# echo 0 > /proc/sys/kernel/watchdog
# echo 0 > /proc/sys/kernel/nmi_watchdog
```

To make these actions permanent, you can edit the `/etc/sysctl.conf` file (or, in newer kernel,
create a new file in the directory `/etc/sysctl.d/`) adding:
```
kernel.watchdog=0
kernel.nmi_watchdog=0
```

- The `ftrace` kernel module is very useful kernel feature for debugging, but it can be the cause of
  very high latencies. To disable it, you can set the `/proc/sys/kernel/ftrace_enabled` to zero or
  edit the `/etc/sysctl.conf` file by adding:
```
kernel.ftrace_enabled=0
```

- Be sure that the kernel verbosity level is not too high (it should at least be < 4) by setting
  the relative sysfs file: `/proc/sys/kernel/printk` or the relative option in `/etc/sysctl.conf`

- Correctly configure the vmstat interval in `/proc/sys/vm/stat_interval`, which is the updater for
  the kernel statistics. Using an high value is suggested (> 60) to reduce the interferences.

### Schedulers and CGroups
#### Schedulers
The tasks run by Linux are scheduled according to the assigned _scheduling policies_. Multiple
schedulers exist in the system, in particular:
- The [CFS scheduler](https://en.wikipedia.org/wiki/Completely_Fair_Scheduler) which schedules the
  tasks with classes `SCHED_OTHER`, `SCHED_IDLE`, and `SCHED_BATCH`. These policies are non
  real-time, so we do not describe them further.
- A FIFO scheduler, for tasks with `SCHED_FIFO` policy
- A Round Robin scheduler, for tasks with `SCHED_RR` policy
- An EDF scheduler, for tasks with `SCHED_DEADLINE` policy

The last three policies are dedicated to the real-time workload. Check the [man page](https://man7.org/linux/man-pages/man7/sched.7.html)
for a detailed description of these modes. How to change the application policy is described in the
next chapter [Configure real-time applications](./configure-apps).

From the system standpoint, some special files in procfs (in particular under `/proc/sys/kernel/`)
are relevant for the real-time workload:
- `sched_deadline_period_min_us` and `sched_deadline_period_max_us`
  allow you to set the minimum and maximum period possible for tasks set as `SCHED_DEADLINE`
- `sched_nr_migrate`: this is a paramter of CFS, but it has a side-impact on
  real-time tasks if this value is high and your system runs many non-real-time tasks. Lower this
  value to 2 to reduce the interference of CFS tasks to real-time tasks ([see here](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/using_sched_nr_migrate_to_limit_sched_other_task_migration.) 
  for further details)
- `sched_rr_timeslice_ms` this is the timeslice (quantum) for RR tasks.
- `sched_rt_runtime_us` / `sched_rt_period_us`: respectively the amount of time to reserve to
  real-time workload over a period. If `sched_rt_runtime_us` is set to -1, no limits are applied to
  real-time workload (warning: your system may become unresponsive due to a spinning real-time
  workload)
- `sched_schedstats`: enable (1) or disable (0) the scheduler statistics generation (you can use the
  `perf` tool to read the statistics). If enabled, it adds a small overhead to the scheduler
  routines.

All the others `sched_*` options are related to CFS and not affecting real-time workload.

### Governors
Most of all the processors that run Linux nowadays are capable of scaling the frequency and the
voltage (DVFS) to control the power consumption. The frequency choice impacts on the execution time,
and thus on your real-time performance. In Linux, DVFS is managed via the `cpufreq` kernel module,
which allows the system administrator to select a _governor_ (i.e., a power management policy) for
each `cpufreq` domain (usually, per-core). The most common governors supported by almost all the
platforms are:
- `performance`: the CPU runs always at the maximum frequency, regardless of the system load
- `powersaving`: the CPU runs always at the minimum frequency, regardless of the system load
- `userspace`:   the CPU runs always at the frequency selected by the user, regardless of the system
  load
- `ondemand`, `conservative`, `schedutil`: the CPU runs at a frequency which depends on the current
  and past system load. Please check the [kernel documentation](https://www.kernel.org/doc/Documentation/cpu-freq/governors.txt)
  for further details. These modes are very effective in the general case, but they are discouraged
  for real-time workload, because they make the execution time unpredictable.

According to the goal of your analysis, the cpu governors (and the frequency if need be) must be
properly set. If the power/energy is not an objective of your analysis, the best choice is usually
the `performance` governor (however, but pay attention to the thermal effects and throttling, see
the next section). The governor is set via sysfs:
```bash
# echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```
Be sure to properly set the required parameters of `cpufre` of all of your CPUs before beginning
the experiment.

#### Hardware throttling
Most of all CPUs implement a hardware throttling of the frequency when the core temperature reaches
a predefined threshold. The frequency is reduced regardless of the governor setting to avoid
hardware damage. Usually, you have no way to control this mechanism (in some chip, you can set
the threshold). Thermal throttling happens frequently when your CPU runs heavy workload with the
governor set to `performance`. To keep the thermal throttling controlled you can implement one or
more of the following solutions:
1. Improve the cooling of your CPU to avoid the thermal throttling by design
2. Change the governor to `powersave` or `userspace` and set a lower frequency
3. Check if a thermal throttle occurs and take action (e.g., you re-run your experiment). To do
   this, you can exploit the files under the sysfs directory
   `/sys/devices/system/cpu/cpu*/thermal_throttle/`, which provide you the number of throttling
   events.

Checking the (non-)happening of the thermal throttling (solution 3.) is, in any case, strongly
suggested, in order to ensure the experiment validity.

#### DPM overheads

### Interrupts


