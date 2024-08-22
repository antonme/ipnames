#!/usr/bin/env fish

cd ~/ipnames
export GCM_CREDENTIAL_STORE=gpg

rm merged/*
ls dns-*.txt| awk '{$nm=substr($0,5,length($0)-8);print "cat dns-"$nm".txt ext-dns-"$nm".txt| sort -u > merged/dns-"$name".txt"}'|bash

ls dns-*.txt| awk '{$nm=substr($0,5,length($0)-8);print "cat ipv6-resolve-"$nm".txt ipv6-ext-resolve-"$nm".txt| rg -v NX | rg -v ^:: | rg :| sort -u | sed \'s/$/\\\\/128/\' > merged/ipv6-"$name}'| bash
ls dns-*.txt| awk '{$nm=substr($0,5,length($0)-8);print "cat resolve-"$nm".txt ext-resolve-"$nm".txt| rg [0-9] | sort -u > merged/ipv4-"$name}'| bash

ls merged/ipv4-*| awk '{print "python3 utils/merge.py --source "$0" > "$0".cidr"}'| bash
ls merged/ipv6-*| awk '{print "python3 utils/merge.py --source "$0" > "$0".cidr"}'| bash

find merged/ -type f ! -name "*.*"| xargs rm
find merged/ -type f -empty -delete
ls merged/ipv4* > merged-ipv4.txt
ls merged/ipv6* > merged-ipv6.txt
ls merged/dns* > merged-dns.txt


git add full-update.fish update.log names-from-cache.fish presolve.fish dns-*.txt ipv6*.txt resolve-*.txt ext-resolve-*.txt cache-ar*.txt ext-dns-*.txt servers*.txt
git commit -m 'auto-update merged'
git push https://{$GITHUB_TOKEN}@github.com/antonme/ipnames.git
