# Manage a cronjob to run r11k
#
# @param git_base_repo local checkkout/mirror or remote of the git repository to deploy to environments.
# @param ensure Value can be either 'present' or 'absent'. Defaults to 'present'.
# @param basedir puppet environments folder location. Defaults to 'this' puppet-server's setting.
# @param cachedir Custom cache dir to use. Defaults to no setting and uses whatever default the script has.
# @param hooksdir Custom hooks dir to use. Defaults to `r11k::default_hooks_dir`.
# @param envhooksdir Custom env hooks dir to use. Defaults to `r11k::default_env_hooks_dir`.
# @param production_branch Set this param to use an alternate git branch as puppet 'production' environment.
# @param flush_cache_cmd Command to flush puppet environment cache.
# @param command_prefix Custom string to prefix the command with. This should be shell safe!
# @param command_suffix Custom string to suffix the command with. This should be shell safe!
# @param job A hash with cron settings passed through to the cronjob.
# @param includes Array (or single String) with regex filters with branches to convert to environments.
define r11k::cron (
  String                          $git_base_repo,
  Enum['present','absent']        $ensure            = 'present',
  Stdlib::Absolutepath            $basedir           = $::settings::environmentpath,
  Optional[Stdlib::Absolutepath]  $cachedir          = undef,
  Optional[Stdlib::Absolutepath]  $hooksdir          = undef,
  Optional[Stdlib::Absolutepath]  $envhooksdir       = undef,
  Optional[String]                $production_branch = undef,
  Optional[Stdlib::Absolutepath]  $flush_cache_cmd   = undef,
  Optional[String]                $command_prefix    = undef,
  Optional[String]                $command_suffix    = undef,
  Hash[String,Any]                $job               = { 'minute' => '*/4', },
  Optional[Variant[String, Array[String]]] $includes = undef,
) {

  $r11k_location = $::r11k::install_location
  $cmd_basedir = ['--basedir', $basedir, '--no-wait']

  $cmd_cachedir = $cachedir ? {
    undef   => [],
    default => ['--cachedir', $cachedir],
  }

  $cmd_hooksdir = $hooksdir ? {
    undef   => ['--hooksdir', $::r11k::default_hooks_dir],
    default => ['--hooksdir', $hooksdir ],
  }

  $cmd_envhooksdir = $envhooksdir ? {
    undef   => ['--envhooksdir', $::r11k::default_env_hooks_dir],
    default => ['--envhooksdir', $envhooksdir ],
  }

  $cmd_production_branch = $production_branch ? {
    undef   => ['--production_branch', $::r11k::default_production_branch],
    default => ['--production_branch', $production_branch ],
  }

  $cmd_flush_cache_cmd = $flush_cache_cmd ? {
    undef   => [],
    default => ['--flush_cache_cmd', $flush_cache_cmd ],
  }

  case $includes {
    undef: { $cmd_includes = [] }
    String: { $cmd_includes = ['--include', $includes] }
    default: {
      if empty ($includes) {
        $cmd_includes = []
      }
      else {
        $cmd_includes = ['--include', join($includes,':')]
      }
    }
  }

  $command_array = flatten([
    $r11k_location,
    $cmd_basedir,
    $cmd_cachedir,
    $cmd_hooksdir,
    $cmd_envhooksdir,
    $cmd_production_branch,
    $cmd_flush_cache_cmd,
    $cmd_includes,
    $git_base_repo,
  ]).filter |$val| { $val =~ NotUndef }
  $safe_command = shell_join($command_array)

  cron {"r11k::cron: ${name}":
    ensure  => $ensure,
    command => "${command_prefix} ${safe_command} ${command_suffix}".strip(),
    require => File[$r11k_location],
    *       => $job,
  }
}
