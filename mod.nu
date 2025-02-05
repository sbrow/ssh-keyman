#!/usr/bin/env nu

# Manage your ssh keyring across multiple machines.
export def ssh-keyman [] {
  # list-hosts
  # | explore

  # [{ host: 104.237.139.52 }]
  # | insert keys { |it|
  #   ssh $it.host 'cat ~/.ssh/authorized_keys'
  #   | from ssh_keys
  # }

  [
    'View authorized_keys'
    'View known_hosts'
  ]
  | input list 'Choose how to proceed'
  | split row ' '
  | last
  | match $in {
    'authorized_keys' => (
      print -e 'Local keyring:';
      ssh-keyman local-keys
    ),
    'known_hosts' => (
      print -e 'Known hosts:';
      ssh-keyman local-hosts
    )
  }
}

# List the keys available in the local keyring
export def "ssh-keyman local-keys" [
]: nothing -> table {
  ssh-add -L | from ssh-keys
}

export def "from ssh-keys" []: string -> table {
  lines
  | where $it !~ '^\s*#'
  | split column ' '
  | rename alg key name
  | select alg key name
  | move name --before alg
}

# List remote hosts that are known about.
export def "ssh-keyman local-hosts" [] {
  open ~/.ssh/known_hosts
  | lines
  | split column ' '
  | rename host alg key
  | sort-by host
  | group-by-key
  | group-by --to-table host 
  # | rename host keys
  # | get host
  # | group-by-key
}

# Group hosts by key
def group-by-key [
]: table<host: string, alg: string, key: string> -> table {
  insert key_hash { |it| $it.key | hash sha256 }
  | group-by key_hash
  | items {|hash, row|
    {
      host: ($row.host | split row ',' | flatten | sort | str join ',')
      alg: $row.alg.0
      key: $row.key.0
    }
  }
}

# List the keys that can log into the remote host.
def remote-keys [
  host: string # The host to connect to
]: nothing -> table {
  ssh $host 'cat ~/.ssh/authorized_keys' | from ssh-keys
}
