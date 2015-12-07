# == Class: bitbucket
#
# This configures the bitbucket module. See README.md for details
#
class bitbucket::config(
  $version      = $bitbucket::version,
  $user         = $bitbucket::user,
  $group        = $bitbucket::group,
  $proxy        = $bitbucket::proxy,
  $context_path = $bitbucket::context_path,
  $tomcat_port  = $bitbucket::tomcat_port,
) {

  File {
    owner => $bitbucket::user,
    group => $bitbucket::group,
  }

  file { "${bitbucket::homedir}/shared":
      ensure  => 'directory',
  } ->

  file { "${bitbucket::webappdir}/bin/setenv.sh":
    content => template('bitbucket/setenv.sh.erb'),
    mode    => '0750',
    require => Class['bitbucket::install'],
    notify  => Class['bitbucket::service'],
  } ->

  file { "${bitbucket::webappdir}/bin/user.sh":
    content => template('bitbucket/user.sh.erb'),
    mode    => '0750',
    require => [
      Class['bitbucket::install'],
      File[$bitbucket::webappdir],
      File[$bitbucket::homedir]
    ],
  } ->

  file { "${bitbucket::homedir}/shared/server.xml":
    content => template('bitbucket/server.xml.erb'),
    mode    => '0640',
    require => Class['bitbucket::install'],
    notify  => Class['bitbucket::service'],
  } ->

  ini_setting { 'bitbucket_httpport':
    ensure  => present,
    path    => "${bitbucket::webappdir}/conf/scripts.cfg",
    section => '',
    setting => 'bitbucket_httpport',
    value   => $tomcat_port,
    require => Class['bitbucket::install'],
    before  => Class['bitbucket::service'],
  } ->

  file { "${bitbucket::homedir}/shared/bitbucket-config.properties":
    content => template('bitbucket/bitbucket-config.properties.erb'),
    mode    => '0750',
    require => [
      Class['bitbucket::install'],
      File[$bitbucket::webappdir],
      File[$bitbucket::homedir]
    ],
    notify  => Class['bitbucket::service'],
  }
}
