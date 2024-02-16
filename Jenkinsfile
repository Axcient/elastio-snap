#!groovy

@Library('jenkins-utils-lib') _

def artifactoryRoot = "replibit/elastio/"
def scriptsDir = ".jenkins/scripts"
def supported_fs = [ 'ext2', 'ext3', 'ext4', 'xfs']

MAX_CONCURENTS = 11
st_locks_count = 0

pipeline
{
	agent
	{
		label 'vagrant_template_label'
	}

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
						values  'empty', //NOTE: for correct draw in OpenBlueOcean
							'DEB', 'RPM',
							'debian9','debian10', 'debian11', 'debian12', // debian8
							'amazon2', 'amazon2023',
							'centos7', 'centos8', 'centos9',
							'alma8', 'alma9',
							'fedora31', 'fedora32', 'fedora34', 'fedora35', 'fedora36', 'fedora37', // 'fedora38',
							'ubuntu2004', 'ubuntu2204'
					}
				}
				stages
				{
					stage('DEB')
					{
						when { expression { env.DISTRO == "DEB" } }
						steps
						{
							node('dr-linbuild')
							{
								sh "bash ./build.sh ${env.BUILD_NUMBER} deb"
								deployDeb dir: "build-results_deb", map_repo: pkg_map_branches('focal-agent'), user: "rbrepo", agent: "rep-agent"
								deployDeb dir: "build-results_deb", map_repo: pkg_map_branches('jammy-agent'), user: "rbrepo", agent: "rep-agent"
								deployDeb dir: "build-results_deb", map_repo: pkg_map_branches('bionic-agent'), user: "rbrepo", agent: "rep-agent"
								deployDeb dir: "build-results_deb", map_repo: pkg_map_branches('bullseye-agent'), user: "rbrepo", agent: "rep-agent"
								deployDeb dir: "build-results_deb", map_repo: pkg_map_branches('buster-agent'), user: "rbrepo", agent: "rep-agent"
								deployDeb dir: "build-results_deb", map_repo: pkg_map_branches('bookworm-agent'), user: "rbrepo", agent: "rep-agent"
								uploadArtifacts files: "build-results_deb/*.deb", dst: "${artifactoryRoot}", postfix: "DEB", shortnames: true, retention : false
							}
						}
					}

					stage('RPM')
					{
						when { environment name: 'DISTRO', value: 'RPM' }
						steps
						{
							node('dr-linbuild')
							{
								sh "bash ./build.sh ${env.BUILD_NUMBER} rpm"
								deployRpm dir: "build-results_rpm", map_repo: pkg_map_branches('ootpa'), user: "rbrepo", agent: "agent"
								deployRpm dir: "build-results_rpm", map_repo: pkg_map_branches('maipo'), user: "rbrepo", agent: "agent"
								deployRpm dir: "build-results_rpm", map_repo: pkg_map_branches('plow'), user: "rbrepo", agent: "agent"
								uploadArtifacts files: "build-results_rpm/*.rpm", dst: "${artifactoryRoot}", postfix: "RPM", shortnames: true, retention : false
							}
						}
					}

					stage('Tests')
					{
						options {
							lock( get_throttle_id() )
						}
						when {
							allOf {
								expression { env.DISTRO != "DEB" }
								expression { env.DISTRO != "RPM" }
								expression { env.DISTRO != "empty" }
							}
						}
						environment {
							DIST_NAME = get_dist_name(DISTRO)
							DIST_VER = get_dist_ver(DISTRO)
							PKG_TYPE = get_type_pkg(DIST_NAME)
							RUNNER_NUM = "1"
							SOURCE_BRANCH = sh returnStdout:true, script: "${scriptsDir}/detect_branch.sh"
							BOX_DIR = "${WORKSPACE}/.jenkins/buildbox"
							ARCH = "amd64"
							BOX_NAME = "${DISTRO}-${ARCH}-build"
							INSTANCE_NAME = "${DISTRO}-${ARCH}-build-${RUNNER_NUM}"
							TEST_DRIVES = "vdb vdc"
							TEST_IMAGES = "${WORKSPACE}/${scriptsDir}/${DISTRO}-test_image1.qcow2 ${WORKSPACE}/${scriptsDir}/${DISTRO}-test_image2.qcow2"
							LIBVIRT_DEFAULT_URI = "qemu:///system"
						}
						stages {
							stage('Start VM')
							{
								steps
								{
									sh "${scriptsDir}/check_env.sh"
									sh ".jenkins/scripts/destroy_box.sh || true"
									sh ".jenkins/scripts/start_box.sh"
								}
							}

//							stage('fail') {steps{ sh "exit 77" }}

							stage('Configure VM')
							{
								steps
								{
									script
									{
										if (DISTRO == 'fedora32' || DISTRO == 'fedora35' || DISTRO == 'fedora36' || DISTRO == 'fedora37')
										{
											echo "Boot Fedora to original kernel"
											sh """
												cd "${BOX_DIR}" &&
												vagrant ssh ${INSTANCE_NAME} -c '
													set -x
													arch=\$(rpm --eval \\%_arch)
													ver=\$(rpm -E \\%fedora)
													case \$ver in
														32)	k_ver=5.9.16
															k_patch=100
															;;
														35)	k_ver=5.15.18
															k_patch=200
															;;
														36)	k_ver=5.17.14
															k_patch=300
															;;
														37)	k_ver=6.0.14
															k_patch=300
															;;
													esac
													for package in "kernel-core" "kernel-modules" "kernel" "kernel-devel"; do
														sudo rpm -ivh --force https://kojipkgs.fedoraproject.org/packages/kernel/\${k_ver}/\${k_patch}.fc\${ver}/\${arch}/\${package}-\${k_ver}-\${k_patch}.fc\${ver}.\${arch}.rpm
													done
												' &&
												vagrant reload ${INSTANCE_NAME}
											"""
										}
										else if (DISTRO == 'debian8')
										{
											echo "Reinstall xfsprogs on Debian 8"
											sh """
												cd "${BOX_DIR}" &&
												vagrant ssh ${INSTANCE_NAME} -c '
													curl --retry 5 --retry-max-time 120 https://s3.eu-central-1.wasabisys.com/blobs-wasabi.elastio.dev/build_utils/xfsprogs_3.2.1.tar.gz | tar xz && cd xfsprogs-3.2.1 &&
													make && sudo make install && sudo make install-dev &&
													cd .. && rm -rf xfsprogs-3.2.1'
											"""
										}
										else if (DISTRO == 'ubuntu2204')
										{
											echo "Install gcc-12 for compile kernel 6.5"
											sh """
												cd "${BOX_DIR}" &&
												vagrant ssh ${INSTANCE_NAME} -c '
													export DEBIAN_FRONTEND=noninteractive
													sudo apt-get update
													sudo  -E apt-get install -y --force-yes gcc-12'
											"""
										}
										else if (DISTRO == 'amazon2' && ARCH == 'arm64')
										{
											// Amazon 2 has installed devtoolset-8 which upgrades GCC from 7.3.1 to 8.3.1.
											// The new gcc doesn't compile rpm packages properly, because of the /usr/lib/rpm/redhat/macros provided
											// by the package system-rpm-config-9.1.0-76.amzn2.0.13.noarch. And this macros has compilation flags applicable
											// for GCC 7 and already removed from GCC 8. The workaround is to disable devtoolset-8 on the next build step.

											echo "Remove toolset for amazon"
											dir("${BOX_DIR}")
											{
												sh "vagrant ssh ${INSTANCE_NAME} -c 'sudo rm /etc/profile.d/enable-llvm-toolset.sh' "
											}
										}

										if (DISTRO != 'debian8')
										{
											echo "Install LVM and RAID tools"
											sh """
												cd "${BOX_DIR}" &&
												vagrant ssh ${INSTANCE_NAME} -c '
													set -x
													if \$(which apt-get >/dev/null 2>&1); then
														export DEBIAN_FRONTEND=noninteractive
														sudo apt-get update
														sudo -E apt-get install -y --force-yes lvm2 mdadm
													else
														# Fedora has rather weak mirrors. But we do not want to have failing builds because of this.
														set +e
														for i in {1..5}; do
															sudo yum install -y lvm2 mdadm && break
															echo "Failed to install LVM and RAID packages. Retrying..."
															sleep 5
															done
														set -e
														mdadm -V
													fi
												'
											"""
										}
									}
								}
							}

							stage('Build kernel module')
							{
								steps
								{
									dir("${BOX_DIR}")
									{
										sh "vagrant ssh ${INSTANCE_NAME} -c 'sudo make'"
										sh "vagrant ssh ${INSTANCE_NAME} -c 'sudo make install'"
									}
								}
							}

							stage('Run tests (loop device)')
							{
								steps
								{
									dir("${BOX_DIR}")
									{
										catchError(stageResult: 'FAILURE')
										{
											script
											{
												for (fs in supported_fs) {
													sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cd tests && sudo ./elio-test.sh -f ${fs}'"
												}
											}
										}
										sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cat tests/dmesg.log; sudo dmesg -c; lsmod'"
									}
								}
							}

							stage('Run tests on LVM (loop device)')
							{
								steps
								{
									dir("${BOX_DIR}")
									{
										catchError(stageResult: 'FAILURE')
										{
											script
											{
												for (fs in supported_fs) {
													sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cd tests && sudo ./elio-test.sh -f ${fs} --lvm'"
												}
											}
										}
										sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cat tests/dmesg.log; sudo dmesg -c; lsmod'"
									}
								}
							}

							stage('Run tests on RAID (loop device)')
							{
								when { expression { env.DISTRO != 'debian8' } }
								steps
								{
									dir("${BOX_DIR}")
									{
										catchError(stageResult: 'FAILURE')
										{
											script
											{
												for (fs in supported_fs) {
													sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cd tests && sudo ./elio-test.sh -f ${fs} --raid'"
												}
											}
										}
										sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cat tests/dmesg.log; sudo dmesg -c; lsmod'"
									}
								}
							}

							stage('Attach qcow2 disks')
							{
								steps
								{
									sh ".jenkins/scripts/attach.sh"
								}
							}

							stage('Run tests (qcow2 disk)')
							{
								steps
								{
									dir("${BOX_DIR}")
									{
										catchError(stageResult: 'FAILURE')
										{
											script
											{
												for (fs in supported_fs) {
													sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cd tests && sudo ./elio-test.sh -d /dev/vdb1 -f ${fs}'"
												}
											}
										}
										sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cat tests/dmesg.log; sudo dmesg -c; lsmod'"
									}
								}
							}

							stage('Run tests on LVM (qcow2 disks)')
							{
								when { expression { env.DISTRO != 'debian8' } }
								steps
								{
									dir("${BOX_DIR}")
									{
										catchError(stageResult: 'FAILURE')
										{
											script
											{
												for (fs in supported_fs) {
													sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cd tests && sudo ./elio-test.sh -d /dev/vdb -d /dev/vdc -f ${fs} --lvm'"
												}
											}
										}
										sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cat tests/dmesg.log; sudo dmesg -c; lsmod'"
									}
								}
							}

							stage('Run tests on RAID (qcow2 disks)')
							{
								when { expression { env.DISTRO != 'debian8' } }
								steps
								{
									dir("${BOX_DIR}")
									{
										catchError(stageResult: 'FAILURE')
										{
											script
											{
												for (fs in supported_fs) {
													//  An issue is observed in virtio driver whith XFS and kernel 3.16 on Debian 8. It's a known issue, it happens on
													// mount of the raid1 device with XFS even if elastio-snap is not loaded. See https://bugzilla.redhat.com/show_bug.cgi?id=1111290
													if (DISTRO == 'debian8' && fs == 'xfs') { continue }

													sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cd tests && sudo ./elio-test.sh -d /dev/vdb -d /dev/vdc  -f ${fs} --raid'"
												}
											}
										}
										sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cat tests/dmesg.log; sudo dmesg -c; lsmod'"
									}
								}
							}

							stage('Run tests multipart  (qcow2 disks)')
							{
								steps
								{
									dir("${BOX_DIR}")
									{
										catchError(stageResult: 'FAILURE')
										{
											script
											{
												for (fs in supported_fs) {
													sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cd tests && sudo ./elio-test.sh -d /dev/vdb -f ${fs} -t test_multipart'"
												}
											}
										}
										sh "vagrant ssh ${env.INSTANCE_NAME} -c 'cat tests/dmesg.log; sudo dmesg -c; lsmod'"
									}
								}
							}

							stage('Stop box')
							{
								steps
								{
									sh ".jenkins/scripts/detach.sh"
									sh ".jenkins/scripts/destroy_box.sh"
								}
							}

						}

						post
						{
							cleanup
							{
								sh ".jenkins/scripts/detach.sh"
								sh ".jenkins/scripts/destroy_box.sh"
							}
						}

					}
				}
			}
		}
	}
	post
	{
		cleanup
		{
			deleteDir()
		}
	}
}

def get_throttle_id()
{
    st_locks_count++
    return 'syncronize_throttle_' + (st_locks_count % MAX_CONCURENTS)
}

def get_dist_name(String distro)
{
	return (distro =~ ~/[a-z]+/).findAll().first().capitalize().replace("os", "OS")
}

def get_dist_ver(String distro)
{
	return (distro =~ ~/\d+/).findAll().first()
}

def get_type_pkg(String dist_name)
{
	if (dist_name == "Debian" || dist_name == "Ubuntu")
	{
		return "deb"
	}

	return "rpm"
}

def pkg_map_branches(String repo)
{
	return [
		'^develop.*': repo + '-dev',
	]
}
