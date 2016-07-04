#! /bin/bash -x

where=$1
origin="local"
label="repo"

# We can't allow $where to leak into Sources and Packages, because those paths
# will not be correct inside the chroot.  Inside the chroot $where gets
# mounted onto $chroot_where.  In the Packages file, this leaks into the
# Filename: line, and in the Sources file, it leaks into the Directory: line.
#
# I'll bet there's an apt-ftparchive -o option to control these,
# (e.g. ArchiveDir and PathPrefix), but I am an idiot and cannot get it to
# work.  Thus, these ugly hacks.  If you have a more elegant solution, email
# me!  barry@ubuntu.com

cd $where
apt-ftparchive sources . \
    | tee "$where"/Sources \
    | gzip -9 > "$where"/Sources.gz

apt-ftparchive packages "$where" \
    | sed "s@$where@@" \
    | tee "$where"/Packages \
    | gzip -9 > "$where"/Packages.gz

# sponge comes from moreutils
apt-ftparchive \
    -o"APT::FTPArchive::Release::Origin=$origin" \
    -o"APT::FTPArchive::Release::Label=$label" \
    -o"APT::FTPArchive::Release::Codename=$where" release "$where" > "$where"/Release
#    | sponge "$where"/Release

#rm -f "$where"/Release.gpg
#cp /var/lib/sbuild/apt-keys/sbuild-key.pub "$where"/repo-key.pub
#gpg --homedir /tmp \
#    --keyring /var/lib/sbuild/apt-keys/sbuild-key.pub \
#    --secret-keyring /var/lib/sbuild/apt-keys/sbuild-key.sec \
#    -abs -o "$where"/Release.gpg "$where"/Release
