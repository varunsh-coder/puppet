test_name "should be able to find an existing filesystem table entry"

confine :except, :platform => ['windows']
confine :except, :platform => /osx/ # See PUP-4823
confine :except, :platform => /solaris/ # See PUP-5201
confine :except, :platform => /^eos-/ # Mount provider not supported on Arista EOS switches
confine :except, :platform => /^cisco_/ # See PUP-5826
confine :except, :platform => /^huawei/ # See PUP-6126

tag 'audit:low',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

require 'puppet/acceptance/mount_utils'
extend Puppet::Acceptance::MountUtils

name = "pl#{rand(999999).to_i}"
name_w_slash = "pl#{rand(999999).to_i}\/"
munged_name = name_w_slash.gsub(%r{^(.+?)/*$}, '\1')

agents.each do |agent|
  fs_file = filesystem_file(agent)

  teardown do
    #(teardown) restore the fstab file
    on(agent, "mv /tmp/fs_file_backup #{fs_file}", :acceptable_exit_codes => (0..254))
  end

  #------- SETUP -------#
  step "(setup) backup #{fs_file} file"
  on(agent, "cp #{fs_file} /tmp/fs_file_backup", :acceptable_exit_codes => [0,1])

  step "(setup) add entry to filesystem table"
  add_entry_to_filesystem_table(agent, name)

  step "(setup) add entry with slash to filesystem table"
  add_entry_to_filesystem_table(agent, name_w_slash)

  #------- TESTS -------#
  step "verify mount with puppet"
  on(agent, puppet_resource('mount', "/#{name}")) do |res|
    fail_test "didn't find the mount #{name}" unless res.stdout.match(/'\/#{name}':\s+ensure\s+=>\s+'unmounted'/)
  end

# There is a discrepancy between how `puppet resource` and `puppet apply` handle this case.
# With this patch, using a resource title with a trailing slash in `puppet apply` will match a mount resource without a trailing slash.
# However, `puppet resource mount` with a trailing slash will not match.
# Therefore, this test cheats by performing the munging that occurs during a manifest application
  step "verify mount with slash with puppet"
  on(agent, puppet_resource('mount', "/#{munged_name}")) do |result|
    fail_test "didn't find the mount #{name_w_slash}" unless result.stdout =~ %r{'/#{munged_name}':\s+ensure\s+=>\s+'unmounted'}
  end

end
