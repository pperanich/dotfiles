git clone --depth 1 https://github.com/$1/$2 /tmp/tmp-repo
git -C /tmp/tmp-repo rev-parse HEAD
rm -rf /tmp/tmp-repo/.git
nix hash path /tmp/tmp-repo
rm -rf /tmp/tmp-repo
