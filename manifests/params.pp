# Class: mongodb::params
#
# Parameters for and from the mongodb module.
#
# Parameters :
#  none
#
# Sample Usage :
#  include mongodb::params
#
class mongodb::params (
  $mongod_version = hiera(mongodb::version, "$::mongod_version"),
  $scl_name       = hiera(mongodb::scl_name, '')
) {
  # sclo
  if ($scl_name and $::operatingsystem =~ /RedHat|CentOS/) {
    $scl_prefix="${scl_name}-"
    $scl_spath="/opt/rh/${scl_name}"
  } else {
    $scl_prefix=''
    $scl_spath=''
  }

  # progname for config, pid and log file as it differs sometime
  case $::operatingsystem {
    'RedHat','CentOS': {
      if versioncmp($::operatingsystemrelease, '7') >= 0 {
        if versioncmp("$mongod_version", '2.6') >= 0 {
          $progname = 'mongod'
        } else {
          $progname = 'mongodb'
        }
        $with_systemd = true
      } else {
        $progname = 'mongodb'
        $with_systemd = false
      }
    }
    default: {
      $progname = 'mongodb'
      $with_systemd = false
    }
  }

  # service
  case $::operatingsystem {
    'RedHat','CentOS': {
      $service = "${scl_prefix}mongod"
    }
    default: {
      $service = "${progname}"
    }
  }

  # start and stop commands
  if ($with_systemd) {
    $service_start = "systemctl start $service"
    $service_stop = "systemctl stop $service"
  } else {
    $service_start = "service $service start"
    $service_stop = "service $service stop"
  }

  # template 
	if versioncmp("$mongod_version", '3.4') >= 0 {
    $template = "${module_name}/mongod-3.4.conf.erb"
  } elsif versioncmp("$mongod_version", '3.0') >= 0 {
	  $template = "${module_name}/mongod-3.0.conf.erb"
	} elsif versioncmp("$mongod_version", '2.6') >= 0 {
	  $template = "${module_name}/mongod-2.6.conf.erb"
	} else {
    $template = "${module_name}/mongodb-2.4.conf.erb"
	}

  # paths
  $conffile = "/etc${scl_spath}/${progname}.conf"
  $dbpath = "/var${scl_spath}/lib/mongodb"
  $runpath = "/var${scl_spath}/run/mongodb"
  $pidfilepath = "${runpath}/${progname}.pid"
  $logpath = "/var${scl_spath}/log/mongodb/${progname}.log"

	# process and file ownership
	$owner = 'mongodb'
	$group = 'mongodb'

  # package(s)
  case $::operatingsystem {
    'Gentoo': { $package = 'dev-db/mongodb' }
    default:  { $package = [ "${scl_prefix}mongodb", "${scl_prefix}mongodb-server" ] }
  }

  if versioncmp("$mongod_version", '2.6') <= 0 {
	  case $::operatingsystem {
	    /(Debian|Ubuntu)/: { $package_tools = 'mongodb-clients' }
	    default:  { $package_tools = false }
	  }
  } else {
	  case $::operatingsystem {
	    'Gentoo': { $package_tools = 'dev-db/mongo-tools' }
	    default:  { $package_tools = "${scl_prefix}mongo-tools" }
	  }
  }
}
