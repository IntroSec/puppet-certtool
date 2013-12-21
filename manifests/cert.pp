define certtool::cert ( $certpath = '/etc/pki/tls/certs',
                        $keypath = '/etc/pki/tls/private',
                        $keybits = 2048,
                        $organization = undef,
                        $unit = undef,
                        $locality = undef,
                        $state = undef,
                        $country = undef,
                        $common_name = $title,
                        $serial = undef,
                        $expiration_days = undef,
                        $uris = undef,
                        $dns_names = undef,
                        $ip = undef,
                        $email = undef,
                        $is_ca = false,
                        $caname = $title,
                        $usage = undef,
                        $use_request_extensions = undef,
                        $crl_dist_points = undef,
                        $challenge_password = undef,
                        $password = undef,
                        $crl_number = undef,
                        $pkcs12_key_name = undef,
                        $extract_pubkey = false) {

  $keyfile = "${keypath}/${title}.key"
  $pubkeyfile = "${keypath}/${title}-pub.key"
  $certfile = "${certpath}/${title}.crt"
  $requestfile = "${certpath}/${title}.csr"
  $cacertfile = "${certpath}/${caname}.crt"
  $cakeyfile = "${keypath}/${caname}.key"
  $template = "${certpath}/certtool-${title}.cfg"

  ensure_resource ( 'file' , [$certpath, $keypath], { ensure  => directory, })

  file { $template:
    ensure   => file,
    owner    => root,
    group    => root,
    mode     => '0640',
    content  => template("${module_name}/certtool.cfg.erb"),
    require => File[$certpath]
  }

  file { $keyfile:
    ensure   => present,
    mode     => '0600',
    owner    => root,
    group    => root,
    require => Exec["certtool-key-${title}"]
  }

  exec { "certtool-key-${title}":
    creates  => $keyfile,
    command  => "certtool --generate-privkey \
                 --outfile ${keyfile} \
                 --bits ${keybits}",
    path     => '/bin:/usr/bin:/sbin:/usr/sbin',
    require => File[$keypath]
  }

  if $extract_pubkey {
    exec { "certtool-pubkey-${title}":
      command => "certtool --load-privkey ${keyfile} --pubkey-info --outfile ${pubkeyfile}",
      path    => '/bin:/usr/bin:/sbin:/usr/sbin',
      creates => $pubkeyfile,
      require => Exec["certtool-key-${title}"]
    }
  }

  if $is_ca == true {
    exec { "certtool-ca-${title}":
      creates  => $certfile,
      command  => "certtool --generate-self-signed --template ${template} \
                   --load-privkey ${keyfile} \
                   --outfile ${certfile}",
      path     => '/bin:/usr/bin:/sbin:/usr/sbin',
      require => [File[$template], File[$keyfile]]
    }
  }
  else {
    exec { "certtool-csr-${title}":
      creates  => $requestfile,
      command  => "certtool --generate-request --template ${template} \
                   --load-privkey ${keyfile} \
                   --outfile ${requestfile}",
      path     => '/bin:/usr/bin:/sbin:/usr/sbin',
      require => [File["${certpath}/certtool-${title}.cfg"], File[$keyfile]]
    }

    exec { "certtool-cert-${title}":
      creates  => $certfile,
      command  => "certtool --generate-certificate --template ${template} \
                   --load-request ${requestfile} \
                   --outfile ${certfile} \
                   --load-ca-certificate ${cacertfile} \
                   --load-ca-privkey ${cakeyfile}",
      path     => '/bin:/usr/bin:/sbin:/usr/sbin',
      require => [Exec["certtool-csr-${title}"], Certtool::Cert[$caname]]
    }
  }
}