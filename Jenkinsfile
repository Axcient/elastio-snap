#!groovy

@Library('jenkins-utils-lib') _
def artifactoryRoot = "replibit/elastio/"

pipeline
{
	agent
	{
		label 'dr-linbuild'
	}
	options
	{
		buildDiscarder(logRotator(numToKeepStr: '10'))
		timestamps ()
	}
	stages
	{
		stage('Build bdsnap package')
		{
			parallel
			{
				stage('DEB')
				{
					steps
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
				stage('RPM')
				{
					steps
					{
						sh "bash ./build.sh ${env.BUILD_NUMBER} rpm"
						deployRpm dir: "build-results_rpm", map_repo: pkg_map_branches('ootpa'), user: "rbrepo", agent: "agent"
						deployRpm dir: "build-results_rpm", map_repo: pkg_map_branches('maipo'), user: "rbrepo", agent: "agent"
						deployRpm dir: "build-results_rpm", map_repo: pkg_map_branches('plow'), user: "rbrepo", agent: "agent"
						uploadArtifacts files: "build-results_rpm/*.rpm", dst: "${artifactoryRoot}", postfix: "RPM", shortnames: true, retention : false
					}
				}
			}
		}
	}
	post
	{
		always
		{
			deleteDir()
		}
	}
}

def pkg_map_branches(String repo)
{
	return [
		'^develop.*': repo + '-dev',
	]
}
