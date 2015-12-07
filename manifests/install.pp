# == Class: bitbucket::install
#
# This installs the bitbucket module. See README.md for details
#
class bitbucket::install(
  $version        = $bitbucket::version,
  $product        = $bitbucket::product,
  $format         = $bitbucket::format,
  $installdir     = $bitbucket::installdir,
  $homedir        = $bitbucket::homedir,
  $manage_usr_grp = $bitbucket::manage_usr_grp,
  $user           = $bitbucket::user,
  $group          = $bitbucket::group,
  $uid            = $bitbucket::uid,
  $gid            = $bitbucket::gid,
  $git_version    = $bitbucket::git_version,
  $repoforge      = $bitbucket::repoforge,
  $downloadURL    = $bitbucket::downloadURL,
  $git_manage     = $bitbucket::git_manage,
  $webappdir
  ) {
  
  if $git_manage {
    if $::osfamily == 'RedHat' and $::operatingsystemmajrelease == '6' {
      validate_bool($repoforge)
      # If repoforge is not enabled by default, enable it
      # but only allow git to be installed from it.
      if ! defined(Class['repoforge']) and $repoforge {
        class { 'repoforge':
          enabled     => [ 'extras', ],
          includepkgs => {
            'extras' => 'git,perl-Git'
          },
          before      => Package['git']
        } ~>
        exec { "${bitbucket::product}_clean_yum_metadata":
          command     => '/usr/bin/yum clean metadata',
          refreshonly => true
        } ~>
        # Git may already have been installed, so lets update it to a 
        # supported version.
        exec { "${bitbucket::product}_upgrade_git":
          command     => '/usr/bin/yum -y upgrade git',
          onlyif      => '/bin/rpm -qa git',
          refreshonly => true,
        }
      }
    }
    package { 'git':
      ensure => $git_version,
    }
  }

  if $manage_usr_grp {
    #Manage the group in the module
    group { $group:
      ensure => present,
      gid    => $gid,
    }
    #Manage the user in the module
    user { $user:
      comment          => 'Bitbucket daemon account',
      shell            => '/bin/bash',
      home             => $homedir,
      password         => '*',
      password_min_age => '0',
      password_max_age => '99999',
      managehome       => true,
      uid              => $uid,
      gid              => $gid,
    }
  }

  if ! defined(File[$installdir]) {
    file { $installdir:
      ensure => 'directory',
      owner  => $user,
      group  => $group,
    }
  }

  # Deploy files using either staging or deploy modules.
  $file = "atlassian-${product}-${version}.${format}"

  require staging

  if ! defined(File[$webappdir]) {
    file { $webappdir:
      ensure => 'directory',
      owner  => $user,
      group  => $group,
    }
  }
  staging::file { $file:
    source  => "${downloadURL}/${file}",
    timeout => 1800,
  } ->
  staging::extract { $file:
    target  => $webappdir,
    creates => "${webappdir}/conf",
    strip   => 1,
    user    => $user,
    group   => $group,
    notify  => Exec["chown_${webappdir}"],
    before  => File[$homedir],
    require => [
      File[$installdir],
      User[$user],
      File[$webappdir] ],
  }

  file { $homedir:
    ensure  => 'directory',
    owner   => $user,
    group   => $group,
    require => User[$user],
  } ->

  exec { "chown_${webappdir}":
    command     => "/bin/chown -R ${user}:${group} ${webappdir}",
    refreshonly => true,
    subscribe   => User[$bitbucket::user]
  }

}
