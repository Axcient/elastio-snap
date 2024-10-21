#!groovy

@Library('jenkins-utils-lib') _

def artifactoryRoot = "replibit/elastio/"

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
	"ubuntu2404" : "noble-agent",

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
						values  'debian8', 'debian9', 'debian10', 'debian11', 'debian12',
							'amazon2', 'amazon2023',
							'centos7', 'centos8', 'centos9',
							'alma8', 'alma9',
							'fedora31', 'fedora32', 'fedora34', 'fedora35', 'fedora36', 'fedora37', 'fedora38', 'fedora40',
							'ubuntu1804', 'ubuntu2004', 'ubuntu2204', 'ubuntu2404',
							'rhel7', 'rhel8', 'rhel9'
					}
				}
				agent {
					label "${DISTRO}_template_label"
				}
				stages
				{
					stage('Update kernel')
					{
						when { expression { env.DISTRO == 'fedora40' } }
						steps
						{
							updateKernelWithReboot()
							checkout scm
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
	sh '[ -f /etc/debian_version ] && (sudo apt update; sudo apt upgrade -y) || sudo yum upgrade -y'

	vSphere buildStep: [$class: 'PowerOff', vm: env.NODE_NAME], serverName: 'vSphere SLC'
	vSphere buildStep: [$class: 'PowerOn', vm: env.NODE_NAME, timeoutInSeconds: 600], serverName: 'vSphere SLC'

	Jenkins.instance.getNode(env.NODE_NAME).getComputer().connect(true)
	sleep(time:30,unit:"SECONDS")
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
