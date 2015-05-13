# File::      <tt>ejabberd.pp</tt>
# Author::    Hyacinthe Cartiaux (hyacinthe.cartiaux@uni.lu)
# Copyright:: Copyright (c) 2012 Hyacinthe Cartiaux
# License::   GPLv3
#
# ------------------------------------------------------------------------------
# = Class: ejabberd
#
# Configure and manage ejabberd
#
# == Parameters:
#
# $ensure:: *Default*: 'present'. Ensure the presence (or absence) of ejabberd
#
# == Actions:
#
# Install and configure ejabberd
#
# == Requires:
#
# n/a
#
# == Sample Usage:
#
#     import ejabberd
#
# You can then specialize the various aspects of the configuration,
# for instance:
#
#         class { 'ejabberd':
#             ensure => 'present'
#         }
#
# == Warnings
#
# /!\ Always respect the style guide available
# here[http://docs.puppetlabs.com/guides/style_guide]
#
#
# [Remember: No empty lines between comments and class definition]
#
class ejabberd(
    $ensure                   = $ejabberd::params::ensure,
    $log_level                = $ejabberd::params::log_level,
    $port_c2s                 = $ejabberd::params::port_c2s,
    $port_s2s                 = $ejabberd::params::port_s2s,
    $port_http_admin          = $ejabberd::params::port_http_admin,
    $s2s_starttls             = $ejabberd::params::s2s_starttls,
    $s2s_default_policy       = $ejabberd::params::s2s_default_policy,
    $certfile_path            = $ejabberd::params::certfile_path,
    $shaper_c2s               = $ejabberd::params::shaper_c2s,
    $shaper_s2s               = $ejabberd::params::shaper_s2s,
    $max_user_sessions        = $ejabberd::params::max_user_sessions,
    $max_user_offline_msg     = $ejabberd::params::max_user_offline_msg,
    $max_admin_offline_msg    = $ejabberd::params::max_admin_offline_msg,
    $default_lang             = $ejabberd::params::default_lang,
    $ldap_server,
    $ldap_encrypt             = $ejabberd::params::ldap_encrypt,
    $ldap_tls_verify          = $ejabberd::params::ldap_tls_verify,
    $ldap_port                = $ejabberd::params::ldap_port,
    $ldap_search_base         = $ejabberd::params::ldap_search_base,
    $ldap_deref               = $ejabberd::params::ldap_deref,
    $ldap_uid_attr            = $ejabberd::params::ldap_uid_attr,
    $ldap_filter              = $ejabberd::params::ldap_filter,
    $vcard_ldap_base          = '',
    $muc_log_dir              = $ejabberd::params::muc_log_dir,
    $muc_log_timezone         = $ejabberd::params::muc_log_timezone,
    $admin                    = $ejabberd::params::admin,
    $register                 = $ejabberd::params::register
)
inherits ejabberd::params
{
    info ("Configuring ejabberd (with ensure = ${ensure})")

    if ! ($ensure in [ 'present', 'absent' ]) {
        fail("ejabberd 'ensure' parameter must be set to either 'absent' or 'present'")
    }

    case $::operatingsystem {
        debian, ubuntu:         { include ejabberd::debian }
        default: {
            fail("Module ${module_name} is not supported on ${::operatingsystem}")
        }
    }
}

# ------------------------------------------------------------------------------
# = Class: ejabberd::common
#
# Base class to be inherited by the other ejabberd classes
#
# Note: respect the Naming standard provided here[http://projects.puppetlabs.com/projects/puppet/wiki/Module_Standards]
class ejabberd::common {

    # Load the variables used in this module. Check the ejabberd-params.pp file
    require ejabberd::params

    # Configuration file
    file { $ejabberd::params::configdir:
        ensure  => 'directory',
        owner   => $ejabberd::params::configdir_owner,
        group   => $ejabberd::params::configdir_group,
        mode    => $ejabberd::params::configdir_mode,
        require => Package['ejabberd'],
    }

    file { $ejabberd::params::configfile:
        ensure  => $ejabberd::ensure,
        path    => $ejabberd::params::configfile,
        owner   => $ejabberd::params::configfile_owner,
        group   => $ejabberd::params::configfile_group,
        mode    => $ejabberd::params::configfile_mode,
        content => template('ejabberd/ejabberd.cfg.erb'),
        require =>  [
                    File[$ejabberd::params::configdir],
                    Package['ejabberd']
                    ],
        notify  => Service[$ejabberd::params::servicename]
    }

    # MUC Log dir
    file { $ejabberd::params::muc_log_dir:
        ensure  => 'directory',
        owner   => $ejabberd::params::muc_log_dir_owner,
        group   => $ejabberd::params::muc_log_dir_group,
        mode    => $ejabberd::params::muc_log_dir_mode,
        require => Package['ejabberd'],
    }


    service { 'ejabberd':
        ensure  => running,
        name    => $ejabberd::params::servicename,
        enable  => true,
        require => [
                    Package['ejabberd'],
                    File[$ejabberd::params::configfile],
                    File[$ejabberd::params::muc_log_dir],
                    ],
    }

}


# ------------------------------------------------------------------------------
# = Class: ejabberd::debian
#
# Specialization class for Debian systems
class ejabberd::debian inherits ejabberd::common {

    if ($::lsbdistid == 'Debian') and ( $::lsbdistcodename == 'squeeze' ) {
        # If Debian Squeeze, use pinning in order to install ejabberd from Wheezy

        apt::source{'wheezy':
            content => "deb http://ftp.fr.debian.org/debian/ wheezy main contrib non-free\n",
        }

        apt::preferences {'wheezy_all':
            package  => '*',
            pin      => 'release n=wheezy',
            priority => 100,
        }

        apt::preferences {'wheezy_ejabberd2110':
            package  => 'erlang-asn1 erlang-base erlang-crypto erlang-inets
              erlang-mnesia erlang-odbc erlang-public-key erlang-runtime-tools
              erlang-ssl erlang-syntax-tools libltdl7 libodbc1 libsctp1 libtinfo5
              lksctp-tools ejabberd',
            pin      => 'release n=wheezy',
            priority => 1500,
        }

        exec { 'ejabberd-apt-update':
            command => 'apt-get update',
            path    => '/usr/bin:/usr/sbin:/bin',
        }

        package { 'ejabberd':
            ensure => $ejabberd::ensure,
            name   => $ejabberd::params::packagename,
        }

        Apt::Source['wheezy'] -> Apt::Preferences['wheezy_all'] -> Apt::Preferences['wheezy_ejabberd2110'] -> Exec['ejabberd-apt-update'] -> Package['ejabberd']

    } else {
        package { 'ejabberd':
            ensure => $ejabberd::ensure,
            name   => $ejabberd::params::packagename,
        }
    }
}




