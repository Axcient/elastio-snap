#!groovy

@Library('jenkins-utils-lib') _

def artifactoryRoot = "replibit/elastio/"
def scriptsDir = ".jenkins/scripts"
def supported_fs = [ 'ext2', 'ext3', 'ext4', 'xfs']

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
							'fedora31', 'fedora32', 'fedora34', 'fedora35', 'fedora36', 'fedora37', 'fedora38',
							'ubuntu1804', 'ubuntu2004', 'ubuntu2204'
					}
				}
				agent {
					label "${DISTRO}_template_label"
				}
				stages
				{
					stage('Build kernel module')
					{
						steps
						{
							sh "sudo make"
							sh "sudo make install"
						}
					}

					stage('Run tests (loop device)') { steps { runTests(supported_fs, "") } }
					stage('Run tests on LVM (loop device)') { steps { runTests(supported_fs, "--lvm") } }
					stage('Run tests on RAID (loop device)') { steps { runTests(supported_fs, "--raid") } }

					stage('Run tests (qcow2 disk)') { steps { runTests(supported_fs, "-d /dev/sdb1") } }
					stage('Run tests on LVM (qcow2 disks)') { steps { runTests(supported_fs, " -d /dev/sdb -d /dev/sdc --lvm") } }
					stage('Run tests on RAID (qcow2 disks)')
					{
						// An issue is observed in virtio driver whith XFS and kernel 3.16 on Debian 8. It's a known issue, it happens on
						// mount of the raid1 device with XFS even if elastio-snap is not loaded. See https://bugzilla.redhat.com/show_bug.cgi?id=1111290
						when { expression { env.DISTRO != 'debian8' } }
						steps { runTests(supported_fs, " -d /dev/sdb -d /dev/sdc --raid") }
					}

					stage('Run tests multipart  (qcow2 disks)') { steps { runTests(supported_fs, "-d /dev/sdb  -t test_multipart") } }
				}
			}
		}
	}
}

def pkg_map_branches(String repo)
{
	return [
		'^develop.*': repo + '-dev',
	]
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
