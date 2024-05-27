#!groovy

// import hudson.model.Node
// import hudson.model.Slave
// import jenkins.model.Jenkins

// Jenkins jenkins = Jenkins.instance
// def jenkinsNodes = jenkins.nodes

// for (Node node in jenkinsNodes) 
// {
    // Make sure slave is online
//    if (!node.getComputer().isOffline()) 
//    {           
        //Make sure that the slave busy executor number is 0.
//        if(node.getComputer().countBusy()==0)
//        {
           // ...Do somthing...
//        }
//    }
// }

@Library('jenkins-utils-lib') _

def artifactoryRoot = "replibit/elastio/"
def build_machine = 'BUILD_RECOVERY_ISO'

def supported_fs = [ 'ext2', 'ext3', 'ext4', 'xfs']

def map_rpm_distro = [
	"centos7" : "maipo",
	"centos8" : "ootpa",
	"centos9" : "plow",
]

def map_deb_distro = [
	"ubuntu1804" : "bionic-agent",
	"ubuntu2004" : "focal-agent",
	"ubuntu2204" : "jammy-agent",

	"debian10" : "buster-agent",
	"debian11" : "bullseye-agent",
	"debian12" : "bookworm-agent",
]

def test_disks = [:]

pipeline
{
	agent none

	options
	{
		buildDiscarder(logRotator(numToKeepStr: '10'))
		timestamps ()
		disableConcurrentBuilds abortPrevious: true
		timeout(time: 6, unit: 'HOURS')
	}
	stages
	{
		stage('Matrix')
		{
			// Trigger builds only for pull requests and specific branches.
			when
			{
				beforeAgent true
				anyOf
				{
					branch pattern: '^(build|release|develop|master|staging).*', comparator: "REGEXP"
					changeRequest()
				}
			}

			matrix
			{
				axes
				{
					axis
					{
						name 'DISTRO'
						values  'fedora39'
					}
				}
				agent {
					label "${DISTRO}_template_label"
				}
				stages
				{
					stage('Update kernel')
					{
						when { expression { env.DISTRO == 'fedora39' } }
						steps
						{
							updateKernelWithReboot()
						}
					}
					stage('Publish packages')
					{
						when { anyOf {
							expression { map_deb_distro[env.DISTRO] != null }
							expression { map_rpm_distro[env.DISTRO] != null }
						} }
						steps
						{
							lock(label: 'elastio-vmx', quantity: 1, resource : null)
							{
								publishPackage(artifactoryRoot, map_deb_distro[env.DISTRO], map_rpm_distro[env.DISTRO])
							}
						}
					}

					stage('Build kernel module')
					{
						// agent {
						//     label "${DISTRO}_template_label"
						// }
						steps
						{
							script { test_disks[env.DISTRO] = getTestDisks() }
							lock(label: 'elastio-vmx', quantity: 1, resource : null)
							{
								sh "sudo make"
								sh "sudo make install"
							}
						}
					}


					stage('Run tests (loop device)') { steps { runTests(supported_fs, "") } }
					stage('Run tests on LVM (loop device)') { steps { runTests(supported_fs, "--lvm") } }
					stage('Run tests on RAID (loop device)') { steps { runTests(supported_fs, "--raid") } }

					stage('Run tests (qcow2 disk)') { steps { runTests(supported_fs, "-d ${test_disks[env.DISTRO][0]}1") } }
					stage('Run tests on LVM (qcow2 disks)') { steps { runTests(supported_fs, " -d ${test_disks[env.DISTRO][0]} -d ${test_disks[env.DISTRO][1]} --lvm") } }
					stage('Run tests on RAID (qcow2 disks)')
					{
						// An issue is observed in virtio driver whith XFS and kernel 3.16 on Debian 8. It's a known issue, it happens on
						// mount of the raid1 device with XFS even if elastio-snap is not loaded. See https://bugzilla.redhat.com/show_bug.cgi?id=1111290
						when { expression { env.DISTRO != 'debian8' } }
						steps { runTests(supported_fs, " -d ${test_disks[env.DISTRO][0]} -d ${test_disks[env.DISTRO][1]} --raid") }
					}

					stage('Run tests multipart  (qcow2 disks)') { steps { runTests(supported_fs, "-d ${test_disks[env.DISTRO][0]}  -t test_multipart") } }
				}
			}
		}
	}
}

def updateKernelWithReboot()
{
	// sh '[ -f /etc/debian_version ] && sudo apt upgrade -y || sudo yum upgrade -y'
	sh 'echo Kernel version: $(uname -r)'
	sh 'ip a'

	try {
		vSphere buildStep: [$class: 'PowerOff', vm: "prefix_fedora39_template_1", timeoutInSeconds: 30], serverName: 'vSphere SLC'
		vSphere buildStep: [$class: 'PowerOn', vm: "prefix_fedora39_template_1", timeoutInSeconds: 600], serverName: 'vSphere SLC'
		// sh 'sudo shutdown -h now'
	} catch (Exception e) {
		vSphere buildStep: [$class: 'PowerOn', vm: "prefix_fedora39_template_1", timeoutInSeconds: 600], serverName: 'vSphere SLC'
	}
	echo "NODE_NAME = ${env.NODE_NAME}"
	def node_name = env.NODE_NAME
	Jenkins.instance.getNode(node_name).getComputer().launch()
	Jenkins.instance.getNode(node_name).getComputer().setAcceptingTasks(true)
	Jenkins.instance.getNode(node_name).getComputer().setTemporarilyOffline(false, null)
	Jenkins.instance.getNode(node_name).getComputer().connect(true)
}

def runTests(def supported_fs, String args)
{
	catchError(stageResult: 'FAILURE')
	{
		try
		{
			for (fs in supported_fs)
			{
				sh "cd tests && sudo ./elio-test.sh -f ${fs} ${args}"
			}
		}
		catch(e)
		{
			sh "cat tests/dmesg.log; sudo dmesg -c; sudo lsmod; sudo rmmod elastio_snap; exit 0"
			throw e
		}
	}
}

def pkgMapBranches(String repo)
{
	return [
		'^develop.*': repo + '-dev',
	]
}

def publishDebPackage(String artifactoryRoot, String deb)
{
	def outDir = "build_results"
	sh """
		sudo make deb RELEASE_NUMBER=${env.BUILD_NUMBER}~`lsb_release -s -c`
		mkdir -p ${outDir} && sudo mv pkgbuild/DEBS/all/*.deb ${outDir} && sudo mv pkgbuild/DEBS/amd64/*.deb ${outDir}
	"""

	def nameDistro = deb.replace("-agent", "").capitalize()
	deployDeb dir: outDir, map_repo: pkgMapBranches(deb), user: "rbrepo", agent: "rep-agent"
	uploadArtifacts files: outDir + "/*.deb", dst: "${artifactoryRoot}", postfix: nameDistro, shortnames: true, retention : true
}

def publishRpmPackage(String artifactoryRoot, String rpm)
{
	def outDir = "build_results"
	sh """
		sudo make rpm RELEASE_NUMBER=${env.BUILD_NUMBER}
		mkdir -p ${outDir} && sudo mv pkgbuild/RPMS/noarch/*.rpm ${outDir} && sudo mv pkgbuild/RPMS/x86_64/*.rpm ${outDir}
	"""

	def nameDistro = rpm.replace("-agent", "").capitalize()
	deployRpm dir: outDir, map_repo: pkgMapBranches(rpm), user: "rbrepo", agent: "agent"
	uploadArtifacts files: outDir + "/*.rpm", dst: "${artifactoryRoot}", postfix: nameDistro, shortnames: true, retention : true
}

def publishPackage(String artifactoryRoot, String deb, String rpm)
{
	catchError(stageResult: 'FAILURE')
	{
		if (deb != null)
		{
			publishDebPackage(artifactoryRoot, deb)
		}
		else if (rpm != null)
		{
			publishRpmPackage(artifactoryRoot, rpm)
		}
	}
}

def getTestDisks()
{
	// All nodes distro images has two 2GiB disks for tests.
	// This code retrieve actual disk names
	sh "lsblk -f"
	return sh (
		script: "sudo fdisk -l | grep 'Disk ' | grep ' 2147483648 bytes' | awk '{print \$2}' | sed 's/://'",
		returnStdout: true
	).split('\n')
}
