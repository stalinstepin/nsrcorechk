# NetWorker - nsrcorechk
**`nsrcorechk`** is a tool that is built to automate the crash analysis process. This will help the customers to collect all the information that the EMC engineer is looking for. This will fasten the troubleshooting process.

The collected details will be analysed in-house and will be passed to the engineering team post that requesting for a fix.
You can view the same information from **[DELL EMC Knowledgebase](https://support.emc.com/kb/518882).**

---

# How do I use it?
* Download the package from the following link:
**[nsrcorechk.tar](https://emcservice--c.na55.content.force.com/servlet/fileField?id=0BEf1000000CoXy)**
* Copy the nsrcorechk.tar file to the host where the NetWorker Binary crashed.
* Extract the package using the following command: **`tar -xvf nsrcorechk.tar`**
* Navigate to nsrcorechk directory which gets created post extraction. Command: **`cd nsrcorechk`**
* Make nsrcorechk.sh script executable as root user using the following command: **`chmod +x nsrcorechk.sh`**
* Run the nsrcorechk.sh script. The scripts within nsrcorechk directory are already given execute permission.
* Once the script starts all that you need to provide is the SR number and the name of the binary that crashed. 

---


# Here is the list of tasks that the script performs:

* Auto-detects OS and uses the associated pkgcore file from within the nsrcorechk directory to collect the required files based on OS. 
* Post OS detection it will change the permission of the corresponding script to an executable. 
* Checks if GDB and pstack is installed. If not, it will as you to install the package which would be used by the nsrcorechk.sh script to debug the core file and will gather the full backtraces for the crash and all its threads. 
* Checks if a core file is generated or not? If not, it uses gcore to automatically generate a core file and runs GDB on the core file to perform the above task.
* Checks if the binary that generated the core, is **`"not stripped"`** or not. If the binary is **`"stripped"`**, then it will display an output, requesting the customer to gather the **`"not stripped"`** binary from EMC.
* Will perform a library dependency check on the binary that crashed and will collect its output to a file.
* Collects NetWorker Client Daemon logs and OS logs in rendered format if the corresponding pattern relevant to crash is identified in the logs. It will create a file which would contain top 20 and bottom 20 lines from the line of matched pattern. This can be modified manually as per users need for extra lines of log review.
* Executes pkgcore against the latest core generated under **`/nsr/cores/${nsr_binary}/core.PID`**
* Compresses all the logs and the pkgcore files **`(core, library files)`**, collected from the above steps.
* Post compression it will perform a cleanup, where all the files collected will be removed expect for the last compressed file. 
* Finally, will display the compressed filename and will display the filename that needs to be upload to the SR.

---

# Screenshots:

![](https://3.bp.blogspot.com/-XMKLt7DpY7c/WuSP6y4z3iI/AAAAAAAAAbQ/WlTK9j2Y3hIlxBtfIDfIwTtPJUWEo2OzgCEwYBhgL/s1600/Allinfo.png)
![](https://1.bp.blogspot.com/-YAA6JPVxs9U/WuSQvHKt5OI/AAAAAAAAAbc/nslkv3Ub6qoLhcnhJ7bwHfsv3IIeFoCzQCEwYBhgL/s1600/LimitedInfo.png)
