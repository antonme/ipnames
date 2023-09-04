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

fish names-from-cache.fish
fish presolve.fish
fish presolve.fish -ext
git add full-update.fish updates.log names-from-cache.fish presolve.fish dns-*.txt resolve-*.txt ext-resolve-*.txt cache-ar*.txt ext-dns-*.txt servers*.txt
git commit -m 'auto-update'
git push https://{$GITHUB_TOKEN}@github.com/antonme/ipnames.git

