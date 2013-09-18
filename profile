#
# profile with RVM
#
ps1_ansible() {
  if test -n "${ANSIBLE_HOSTS}"; then
    echo "$(basename ${ANSIBLE_HOSTS%%.ansible}) "
  fi
}

ps1_cmonkey() {
  if test -n "${CMONKEY_HOSTS}"; then
    echo "@ $(basename ${CMONKEY_HOSTS%%.cmonkey}) "
  fi
}

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
source "$rvm_path/contrib/ps1_functions"
ps1_prefix="(\$?)\\$ \$(ps1_ansible)\$(ps1_cmonkey)"
ps1_set --prompt "ME"
