# Class: mongodb::auth
#
# Allow basic management of users and roles
# by creating at least a root user
# and any extra users defined from a hash
# For instance:
#
# include mongodb::auth
# 
# class { 'mongodb::auth'
#   root_password: 'secret',
#   users: { foo: { password: 'secret', roles: '[ "readWrite" ]', dbname: 'foodata' } }
#
# The unix root user will be provided with a ~/.mongorc.js script
# which is required to support updating Mongo DB root password
#
class mongodb::auth (
  $root_password,
  $root_username  = 'root',
  $root_dbname    = 'admin',
  $users          = {},
) {
  include mongodb

  Exec {
    path      => [ '/bin', '/sbin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin', ],
    logoutput => true,
  }

  Class['mongodb'] ->
  anchor{ 'mongo-auth-begin': } ->

  # Create mandatory root user with empty rc
  # To trigger the initialization of the root user if needed 
  exec { 'mongo-rc-root-init':
    command => "touch '/root/.mongorc.js'",
    unless  => "test -s '/root/.mongorc.js'",
  } ~>

  # Restart mongod without authentication to initialize root user 
  exec { 'mongo-auth-disable-restart':
    command => $mongodb::scl_name ? {
      ''      => "${mongodb::service_stop} && runuser -g ${mongodb::group} -s /bin/sh ${mongodb::owner} /bin/sh -c 'mongod --noauth -f ${mongodb::conffile} run'",
      default => "${mongodb::service_stop} && runuser -g ${mongodb::group} -s /bin/sh ${mongodb::owner} /bin/sh -c 'scl enable ${mongodb::scl_name} -- mongod --noauth -f ${mongodb::conffile} run'",
    },
    onlyif  => "pgrep mongod >/dev/null 2>&1",
    refreshonly => true,
  } ~>

  # Wait for mongod to be online w/o authentication
  exec { 'mongo-auth-disable-wait':
    command      => "echo 'exit' | scl enable ${mongodb::scl_name} -- mongo |& grep -v '^exception: connect failed'",
    tries        => 15,
    try_sleep    => 2,
    logoutput    => on_failure,
    refreshonly  => true,
    notify       => Exec['mongo-auth-disable-stop'],
  } ->

  # Add root user and rc file to create other users if required
  mongodb::auth::user { "${root_username}":
    password  => "${root_password}",
    roles     => '[ "root" ]',
    login_username => '',
    login_password => '',
    local_username => 'root',
    local_userhome => '/root',
  } ->

  # Stop mongod w/o authentication
  exec { 'mongo-auth-disable-stop':
    command => "pkill -TERM --full 'mongod --noauth'",
    refreshonly => true,
  } ~>

  # Start mongod with authentication
  exec { 'mongo-auth-enable-start':
    command => "${mongodb::service_start}",
    refreshonly => true,
  } ~>

  exec { 'mongo-auth-enable-wait':
    refreshonly  => true,
    command      => "echo 'exit' | scl enable ${mongodb::scl_name} -- mongo |& grep -v '^exception: connect failed'",
    tries        => 15,
    try_sleep    => 2,
    logoutput    => on_failure,
  } ->

  anchor{ 'mongo-auth-enabled': }

  # Create optional users
  create_resources(mongodb::auth::user, $users)

  anchor { 'mongo-auth-end': }
}
