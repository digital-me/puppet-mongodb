# Define: mongodb::auth::user
#
# Example Usage:
#   mongodb::auth::user { foo:
#     password => 'secret',
#     dbname   => 'foodata',
#     roles:   => '[ "readWrite" ]',
#   }
#
# REM: roles need to be passed as a valid JSON string
# For more info about the syntax:
#   https://docs.mongodb.com/manual/reference/command/createRole/#roles
#
# In case local_username is set, the corresponding user
# will be provided with a ~/.mongorc.js script to automate
# its login when starting the Mongo shell
# 
define mongodb::auth::user (
  $password,
  $username = "$name",
  $dbname   = 'admin',
  $ensure   = 'present',
  $roles    = '[ "readWriteAnyDatabase" ]',
  $scl_name = "$mongodb::scl_name",
  $login_username = "$mongodb::auth::root_username",
  $login_password = "$mongodb::auth::root_password",
  $login_dbname = "$mongodb::auth::root_dbname",
  $local_username  = false,
  $local_userhome = false,
) {
  include mongodb::auth

  # Make sure root user is created first
  # Just in case the resource is called directly
  if ($username != $mongodb::auth::root_username) {
    Anchor['mongo-auth-enabled'] ->
    Exec["user-${username}"]
  }

  $net_port = $mongodb::net_port
  $net_host = $mongodb::net_host
  $net_ssl  = $mongodb::net_ssl

  # Construct the correct command line to call Mongo shell
  if ($scl_name) {
    $mongo_cmd = "scl enable ${scl_name} -- mongo --quiet"
  } else {
    $mongo_cmd = "mongo --quiet"
  }

  # Add network arguments as required
  if ($net_ssl and $net_ssl['mode'] and $net_ssl['mode'] != 'disabled' ) {
    $mongo_net_arg = "--port $net_port --host $net_host --ssl"
    $net_ssl_enabled = true
  } else {
    $mongo_net_arg = "--port $net_port --host $net_host"
    $net_ssl_enabled = false
  }

  # Add login arguments if relevant
  if ($login_username) { 
    $mongo_user_arg = " -u '${login_username}'"
  }
  if ($login_password) {
    $mongo_pwd_arg = " -p '${login_password}'"
  }
  if ($login_dbname) {
    $mongo_db_arg = "'${login_dbname}'"
  }

  Exec {
    path => [ '/bin', '/sbin', '/usr/bin', '/usr/sbin', '/usr/local/bin', '/usr/local/sbin', ],
  }

  case $ensure {
    'absent': {
      # FIXME
    }
    'present': {
      $script = template('mongodb/auth/user.js.erb')

      # Create the user using root rc and the template script
      exec { "user-${username}":
        provider => 'shell',
        command => "{ cat /root/.mongorc.js; cat <<EOF
${script}
EOF
} | ${mongo_cmd} ${mongo_net_arg} ${mongo_db_arg}",
        unless  => [ # The authentication already works...
          "${mongo_cmd} ${mongo_net_arg} -u ${username} -p ${password} ${dbname}",
        ],
        logoutput => on_failure,
      } ->
      Anchor['mongo-auth-end']

      if ($local_userhome) {
        $rc_path = "$local_userhome/.mongorc.js"
      } else {
        $rc_path = "/home/${local_username}/.mongorc.js"
      }

      if ($local_username) {
        # Create rc file for the user if required
        file { "mongo-rc-${username}":
          path      => "${rc_path}",
          content   => template('mongodb/auth/rc.js.erb'),
          owner     => "${local_username}" ? {
            true    => "${username}",
            default => "${local_username}",
          },
          mode      => '0600',
          require   => Exec["user-${username}"],
          show_diff => false,
        } ->
        Anchor['mongo-auth-end']
      }
    }
    default: {
      notice('Unknown value for ensure')
    }
  }
}
