
**Intro**

This set of scripts enable you to benchmark Azure Blob Storage accounts. It creates the accounts, implement a TIG (Telegraph / InfluxDB / Grafana) environment, installs all required packages to run read and writes to and from the storage accounts.
You'll need to have a [CycleCloud](https://docs.microsoft.com/en-us/azure/cyclecloud/?view=cyclecloud-7) cluster up and runing with SLURM as a preliminary step.

**How To**

**1.** You need to create storage accounts first, you can use the script master/generate_SAS.sh to do so which uses [azcli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest). So please start by installing azcli, then login to your subscription.

The script will create storage accounts in the resource group you've selected and generate an output file containing the proper informations to use the storage accounts from the compute nodes.

*Example :*

**Update variables**
<pre>
# Number of storage account you wish to create
NUMBER_STG_ACCOUNTs=20
# Storage account name prefix, must be uniq so use your own
STG_ACCOUNT_PREFIX="benchtest2020"
# Output file name which will be used by other scripts
OUTPUT_File="SAS.keys"
# Resource group name in your subscription
rg="benchtest"
# Region where you wish to create the storage accounts
location="westeurope"
</pre>

<pre>
husiana@DESKTOP-RGH24T0:~/BenchBlobStorage/master$ ./generate_SAS.sh

Creating stg account benchtest2020000
STG000="https://benchtest2020000.blob.core.windows.net/"

Creating stg account benchtest2020001
STG001="https://benchtest2020001.blob.core.windows.net/"
...
husiana@DESKTOP-RGH24T0:~/BenchBlobStorage/master$ head -6 SAS.keys
STG000="https://benchtest2020000.blob.core.windows.net/"
SAS000="?st=2020-05-19T09%3A45%3A38Z&se=2021-05-19T11%3A45%3A38Z&sp=rwl&sv=2018-03-28&ss=b&srt=sco&sig=KGX79lEUiE1cSoPcq9FXcXX0WrDEXOTZEATFCmATC8U%3D"
STG001="https://benchtest2020001.blob.core.windows.net/"
SAS001="?st=2020-05-19T09%3A45%3A38Z&se=2021-05-19T11%3A45%3A38Z&sp=rwl&sv=2018-03-28&ss=b&srt=sco&sig=%2BTFyKOhJU%2BsAlWKVO3y5%2BUWQveX1sFnbnIpMb/gmcGQ%3D"
STG002="https://benchtest2020002.blob.core.windows.net/"
SAS002="?st=2020-05-19T09%3A45%3A38Z&se=2021-05-19T11%3A45%3A38Z&sp=rwl&sv=2018-03-28&ss=b&srt=sco&sig=pnsOACskJClqnr7u2Ao06w86zpeUeAp9YMHP57/fk3g%3D"
</pre>

**2.** Create your SLURM cluster, one master and xxx HTC nodes
	In this example, I will use 10 x D16sv3 nodes along with 5 x Storage accounts. I expect to have 8Gbps per node, 16Gbps per storage account == 80Gbps total bandwidth.

**3.** Login to your SLURM Master node :

- scp all the scripts files to your home dir
- execute the scripts (as root, with sudo) master/0-git-config.sh
- edit the slurm config file to modify timeout values :
<pre>
[husiana@ip-0A000006 ~]$ sudo vi /etc/slurm/slurm.conf
[husiana@ip-0A000006 ~]$ grep -i time !$
grep -i time /etc/slurm/slurm.conf
ResumeTimeout=64000
SuspendTimeout=64000
SuspendTime=64000
</pre>
- reboot the master node

**4.** Create an ssh tunel to access the Grafana dashboard

- ssh -i .ssh/id_rsa_azure -N -L 8080:127.0.0.1:3000 USER@IPADDRESS-MASTER
- You'll now be able to access the dashboard by browsing localhost:8080 on Edge, Chrome, etc.
- Credentials are stored on the scripts used in step 3 :
<pre>
[husiana@ip-0A000006 master]$ head -4 0-git-config.sh
#!/bin/bash

GRAFANA_USER="admin"
GRAFANA_PASSWD="P@sswOrd4242020"
</pre>

**5.** Now, from CycleCloud, you can manually start your htc nodes, in my case my 10 x D16sv3

- monitor if they are up with sinfo from the master node :
<pre>
[husiana@ip-0A000006 execute]$ srun -p htc -w htc-[1-10] hostname | wc -l
10
</pre>

**6.** So let's configure the htc nodes now :

- install pdsh on master : sudo yum -y install pdsh
- in the execute directory, create a file containing part of the ip adress of the node such as :
<pre>
[husiana@ip-0A000006 execute]$ srun -p htc -w htc-[1-10] ifconfig eth0 | awk '{if ($0 ~ /inet /) {print $2}}' | cut -d "." -f 3,4 | sort -n > nodelist.txt
[husiana@ip-0A000006 execute]$ cat nodelist.txt
0.10
0.11
0.12
0.13
0.14
0.15
0.16
0.7
0.8
0.9
</pre>

This will allow you to write data only once to the storage accounts.

- still in the execute directory, create a machine file for pdsh, such as :
<pre>
[husiana@ip-0A000006 execute]$ srun -p htc -w htc-[1-10] ifconfig eth0 | awk '{if ($0 ~ /inet /) {print $2}}' > htcnodes.txt
[husiana@ip-0A000006 execute]$ cat htcnodes.txt
10.0.0.8
10.0.0.12
10.0.0.7
10.0.0.16
10.0.0.13
10.0.0.11
10.0.0.14
10.0.0.10
10.0.0.15
10.0.0.9
</pre>

- now, install packages on htc nodes :
<pre>
# This script installs telegraf and configures it to send data to the InfluxDB database runing on master node :
pdsh -f `cat nodelist.txt | wc -l` -w ^htcnodes.txt sudo ~/BenchBlobStorage/execute/0-telegraf.sh
# This one installs missing packages :
pdsh -f `cat nodelist.txt | wc -l` -w ^htcnodes.txt sudo ~/BenchBlobStorage/execute/1-pkg_install.sh
# This one installs azcopy :
pdsh -f `cat nodelist.txt | wc -l` -w ^htcnodes.txt sudo ~/BenchBlobStorage/execute/2-azcopy.sh
# This one installs iozone and create 100GB empty files on the /mnt/resource directory (so takes longer to run), you can start to monitor nodes activity on grafana :
pdsh -f `cat nodelist.txt | wc -l` -w ^htcnodes.txt sudo ~/BenchBlobStorage/execute/3-iozone.sh
...
10.0.0.11:      Children see throughput for  1 initial writers  =  302980.50 kB/sec
10.0.0.12:      Children see throughput for  1 initial writers  =  302805.03 kB/sec
10.0.0.15:      Children see throughput for  1 initial writers  =  303576.34 kB/sec
10.0.0.7:       Children see throughput for  1 initial writers  =  302753.22 kB/sec
10.0.0.8:       Children see throughput for  1 initial writers  =  302846.19 kB/sec
10.0.0.13:      Children see throughput for  1 initial writers  =  302646.16 kB/sec
10.0.0.10:      Children see throughput for  1 initial writers  =  302665.62 kB/sec
10.0.0.16:      Children see throughput for  1 initial writers  =  302399.16 kB/sec
10.0.0.9:       Children see throughput for  1 initial writers  =  302877.12 kB/sec
10.0.0.14:      Children see throughput for  1 initial writers  =  302542.88 kB/sec
</pre>

**7.** Nodes are now ready, as well as storage accounts. We can start to write data to your storage accounts :

- edit the script *4-writes.sh*, double check its content and edit required settings (path to SAS.keys, number of storage accounts, nodes, etc.)
- Run it using pdsh (srun will kill it if it exceeds defined timeout, it's hard to now how long it's gonna take) such as :
<pre>
pdsh -f `cat nodelist.txt | wc -l` -w ^htcnodes.txt sudo ~/BenchBlobStorage/execute/4-writes.sh
</pre>
- Now, you can check with azcopy list the content of your storage containers, in this example, you should have 2 files per container, one container per node.
- Next major update of this script will, instead of re-writing the same file from compute nodes to storage account, copy the first uploaded blob to an other location. This way will be much more efficient.

**8.** Now you can start the reads, we will read the 2 files in parallel (with default settings) to improve bandwidth so each nodes will not be limited by local SSD throughput to read from ADLS. 2 x azcopy will run in // using taskset and the tool parallel. Each will use 4 x cores.
- I recommend to run it once using pdsh so you know how long it takes to read the 2 files per node, then you can re-run it with srun specifying a deadline.
<pre>
time pdsh -f `cat nodelist.txt | wc -l` -w ^htcnodes.txt sudo ~/Validationscripts/execute/5-reads.sh
...
real    2m5.118s
user    0m2.088s
sys     0m1.021s
</pre>

- In this example, I'm reading 2 Files or 100GB each per node == 2 x 100 x 10 = 2TB of data read within 165 seconds. It represents 96Gbps (2*100*10/165*8) but, as all reads don't start and ends at the same time, this bandwidth might be improved. Let's kill the reads after 150 seconds using step 9 below.

**9.** Let's use slurm to run 150seconds jobs, such as :

<pre>
[husiana@ip-0A000006 execute]$ cat runbenchread.sh
#!/bin/bash

NODELST=htc-[1-10]
NODECNT=10
CPUPTASK=16
PART="htc"
</pre>

## Run the show from client nodes :
<pre>
srun -l -p $PART -w $NODELST -N $NODECNT -t "2:30" --cpus-per-task $CPUPTASK -o ~/Validationscripts/execute/logs/readlogs.txt sudo ~/BenchBlobStorage/execute/5-reads.sh
</pre>

- Now you can check logs (readlogs.txt) to see if threads were killed before to be completed and reduce the time it runs to ensure all threads are still runing when killed. 

**10.** think about cleaning up your storage accounts... You can either delete the resource group used when you created them or use the script master/delete_STG.sh

