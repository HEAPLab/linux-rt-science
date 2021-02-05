## Realtime Check Scripts
This is a collection of scripts for diagnosing realtime linux environments

### Requirements
For the scripts to work the following programs need to be present
* `bash`
* `gnu coreutils` or equivalent (eg. busybox or toybox)
* `sed`
* `grep`
* `gzip` (to read /proc/config.gz if present)
* `procps`

#### rtsyscheck
Checks if the system is configured correctly for RT

#### rtps
simple ps-like program to list RT applications
```
Syntax: rtps [-k] [-f|-r|-b|-i|-d]

        -k      also show kernel threads

    Scheduling Selection
        -f      only show FIFO processes
        -r      only show Round-Robin processes
        -b      only show Bulk processes
        -i      only show Idle processes
        -d      only show Deadline processes
```

#### rtproc
Prints information about a list of processes
```
Syntax: rtproc -p pid1[,pid2,pid3...]
        rtproc programname
```
