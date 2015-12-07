
# == Class: bitbucket::backup
#
# This installs the bitbucket backup client
#
class bitbucket::backup(
  $ensure               = $bitbucket::backup_ensure,
  $backupuser           = $bitbucket::backupuser,
  $backuppass           = $bitbucket::backuppass,
  $version              = $bitbucket::backupclientVersion,
  $product              = $bitbucket::product,
  $format               = $bitbucket::format,
  $homedir              = $bitbucket::homedir,
  $user                 = $bitbucket::user,
  $group                = $bitbucket::group,
  $downloadURL          = $bitbucket::backupclientURL,
  $s_or_d               = $bitbucket::staging_or_deploy,
  $backup_home          = $bitbucket::backup_home,
  $javahome             = $bitbucket::javahome,
  $keep_age             = $bitbucket::backup_keep_age,
  ) {

  $appdir = "${backup_home}/${product}-backup-client-${version}"


  file { $backup_home:
    ensure => 'directory',
    owner  => $user,
    group  => $group,
  }
  file { "${backup_home}/archives":
    ensure => 'directory',
    owner  => $user,
    group  => $group,
  }

  # Deploy files using either staging or deploy modules.
  $file = "${product}-backup-distribution-${version}.${format}"
  case $s_or_d {
    'staging': {
      require staging
      file { $appdir:
        ensure => 'directory',
        owner  => $user,
        group  => $group,
      }
      staging::file { $file:
        source  => "${downloadURL}/${version}/${file}",
        timeout => 1800,
      } ->
      staging::extract { $file:
        target  => $appdir,
        creates => "${appdir}/lib",
        strip   => 1,
        user    => $user,
        group   => $group,
        require => User[$user],
      }
    }
    'deploy': {
      #fail('only "staging" is supported for backup client')
      deploy::file { $file:
        target          => $appdir,
        url             => $downloadURL,
        strip           => true,
        owner           => $user,
        group           => $group,
        download_timout => 1800,
        #notify          => Exec["chown_${webappdir}"],
        require         => [
          File[$backup_home],
          User[$user] ]
      }
    }
    default: {
      fail('staging_or_deploy parameter must equal "staging" or "deploy"')
    }
  }

  if $javahome {
    $java_bin = "${javahome}/bin/java"
  } else {
    $java_bin = '/usr/bin/java'
  }

  # Enable Cronjob
  $backup_cmd = "${java_bin} -Dbitbucket.password=\"${backuppass}\" -Dbitbucket.user=\"${backupuser}\" -Dbitbucket.baseUrl=\"http://localhost:7990\" -Dbitbucket.home=${homedir} -Dbackup.home=${backup_home}/archives -jar ${appdir}/bitbucket-backup-client.jar"

  cron { 'Backup Bitbucket':
    ensure  => $ensure,
    command => $backup_cmd,
    user    => $user,
    hour    => 5,
    minute  => 0,
  }

  tidy { 'remove_old_archives':
    path    => "${backup_home}/archives",
    age     => $keep_age,
    matches => '*.tar',
    type    => 'mtime',
    recurse => 1,
  }

}
