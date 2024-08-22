#!/usr/bin/env fish

echo
echo
echo
echo --------------------------------------------------------------------------------
date
echo
echo "==> Beginning ipnames update."
echo
echo --------------------------------------------------------------------------------

cd /home/anton/ipnames
export GCM_CREDENTIAL_STORE=gpg

fish names-from-cache.fish


git add full-update.fish update.log names-from-cache.fish presolve.fish dns-*.txt ipv6*.txt resolve-*.txt ext-resolve-*.txt cache-ar*.txt ext-dns-*.txt servers*.txt
git commit -m 'auto-update names'
git push https://{$GITHUB_TOKEN}@github.com/antonme/ipnames.git

fish presolve6.fish -ext

git add full-update.fish update.log names-from-cache.fish presolve.fish dns-*.txt ipv6*.txt resolve-*.txt ext-resolve-*.txt cache-ar*.txt ext-dns-*.txt servers*.txt
git commit -m 'auto-update ipv6'
git push https://{$GITHUB_TOKEN}@github.com/antonme/ipnames.git

