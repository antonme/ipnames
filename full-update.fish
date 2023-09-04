echo Beginning ipnames update.
date

cd /home/anton/dev/ipnames

fish names-from-cache.fish
fish presolve.fish
fish presolve.fish -ext
git add full-update.fish updates.log names-from-cache.fish presolve.fish dns-*.txt resolve-*.txt ext-resolve-*.txt cache-ar*.txt ext-dns-*.txt servers*.txt
git commit -m 'auto-update'
git push https://{$GITHUB_TOKEN}@github.com/antonme/ipnames.git

