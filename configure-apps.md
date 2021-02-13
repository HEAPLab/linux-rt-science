[Back to Index](./)

## Achieving real-time in applications
Once the system has been configure, you have to tell Linux that your application is a real-time
application. Moreover, you have to take some precautions regarding page swapping mechanisms of
the Linux kernel which would potentially introduce spurious latencies. Before entering the details,
it is important to clarify the Linux terminology:
- **Process**: this is an instance of your application, possibly multi-threading
- **Thread**: the basic unit of computation running sequentially in one core
- **Task**: there is not a general meaning of "task" in Linux, but it is sometimes used as a synonym
  of thread.

### Nice vs Priority
The CFS scheduler uses the `nice` value to prioritize application. The lower the `nice` value for a
process/thread, the higher the CPU share is assigned to this task, according to the CFS policy.
Instead, when a real-time fixed-prioity class (`SCHED_RR` or `SCHED_FIFO`) is applied to a task,
the `nice` value is ignored, and the `priority` value is, instead, used. High priority tasks preempt
lower priority tasks. The dynamic priority scheduler `SCHED_DEADLINE` ignores both `nice` and
`priority` values and tasks with such scheduling policy preempt any other tasks in the system.

### Minimal setup
To configure an application to run in real-time you have to perform the following actions:
1. Set the scheduler policy and priority
2. Set the CPU affinity
3. Lock the memory

#### Configure via C interface

##### Scheduler policy and priority
To set the scheduler policy and priority of the current thread in C, you can run the following code:
```c
struct sched_param schd;
schd.sched_priority = 10;
sched_setscheduler(0, SCHED_FIFO, &schd);
```
Replacing the `0` with the PID of another thread allows your program to set the real-time priority
of another thread. Please check the [related documentation](https://man7.org/linux/man-pages/man2/sched_setscheduler.2.html)
for further details of the parameters.

> :warning: Do not confuse the `setpriority()` function, which actually sets the `nice` value, not
> the priority! You have to use the `sched_setscheduler` to set the real-time priority.

If you are using `SCHED_DEADLINE` check the [sched_setattr() documentation](https://man7.org/linux/man-pages/man2/sched_setattr.2.html)
to learn how to configure period, deadline, etc.

##### CPU affinity
The CPU affinity allows you to specify on which CPU you would like to run your thread. For a
real-time application, you should set the cores you have indicated as `isolcpus` in the
[previous step](./configure-system). You can specify one or more CPU ids. However, if you specify
more than one CPU, Linux decides where to run and this may introduce latencies: Linux can decide to
migrate your thread in the middle of execution, causing an overhead due to core migration to your
thread.

Example - set the affinity of the current thread to cpu 3:
```c
cpu_set_t set;
CPU_ZERO(&set);
CPU_SET(3, &set);

sched_setaffinity(0, sizeof(set), &set);
```
Please check the [related documentation](https://man7.org/linux/man-pages/man2/sched_setaffinity.2.html)
for further details of the parameters.

##### Lock the memory
To prevent Linux to swap-out your memory causing extremely high latency, it is important that you
lock the memory of your process:

```c
mlockall(MCL_CURRENT | MCL_FUTURE);
```

You do not have to run this function per-thread, because it is a per-process flag. Please check the
[related documentation](https://man7.org/linux/man-pages/man2/mlockall.2.html) for further
details of the parameters.

#### Configure via shell commands



[Back to Index](./)
