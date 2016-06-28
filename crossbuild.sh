#!/bin/sh

# TODO:
# - option to cleanup device
# - option to cleanup container
# - add option to force installation of dependencies
# - make it faster: bypass apt update
# - implement a 'make install' version
# - figure out the subuids
# - script lxd on zfs install

PACKAGES_TO_DEPLOY=$@
TARGET_ARCH=armhf
PACKAGE=`dpkg-parsechangelog --show-field Source`
PACKAGE_VERSION=`dpkg-parsechangelog --show-field Version`
NEW_PACKAGE_VERSION=$PACKAGE_VERSION-local~`date +%s`
LXD_CONTAINER=$PACKAGE-$TARGET_ARCH-builder
DEVICE_PASSWORD=0000
USERNAME=`id --user --name`
GROUPNAME=$USERNAME
USERID=150000
GROUPID=150000
USERDIR=/home/$USERNAME
MOUNT_POINT=$USERDIR/$PACKAGE
SCRIPT_DIR=`dirname $0`
DEBS_TARBALL=built_debs.tar
CREATE_REPO_SCRIPT=create_repository.sh
PARALLEL_BUILD=8


exec_device () {
    echo adb shell "$@"
    adb shell "$@"
}

exec_container_root () {
    command="$@"
    echo lxc exec $LXD_CONTAINER "$@"
    lxc exec $LXD_CONTAINER -- sh -c "cd $MOUNT_POINT; $command"
}

exec_container () {
    command="$@"
    echo lxc exec $LXD_CONTAINER "$@"
    lxc exec $LXD_CONTAINER -- su -c "cd $MOUNT_POINT; $command" $USERNAME
}

# setup the crossbuilding container
lxc info $LXD_CONTAINER > /dev/null 2>&1
CONTAINER_EXISTS=$?
if [ $CONTAINER_EXISTS -eq 0 ] ; then
  :
  lxc config device add $LXD_CONTAINER mymount disk source=$PWD path=$MOUNT_POINT
  lxc start $LXD_CONTAINER
else
  lxc remote --protocol=simplestreams --public=true --accept-certificate=true add sdk https://sdk-images.canonical.com
  lxc init sdk:ubuntu-sdk-15.04-amd64-$TARGET_ARCH-dev $LXD_CONTAINER
  printf "lxc.id_map = g $GROUPID `id --group` 1\nlxc.id_map = u $USERID `id --user` 1" | lxc config set $LXD_CONTAINER raw.lxc -
  lxc start $LXD_CONTAINER
  lxc exec --env GROUPID=$GROUPID --env GROUPNAME=$GROUPNAME $LXD_CONTAINER -- addgroup --gid $GROUPID $GROUPNAME
  lxc exec --env GROUPID=$GROUPID --env USERNAME=$USERNAME --env USERID=$USERID $LXD_CONTAINER -- adduser --disabled-password --gecos "" --uid $USERID --gid $GROUPID $USERNAME
  lxc exec --env USERNAME=$USERNAME $LXD_CONTAINER -- usermod -aG sudo $USERNAME
  lxc config device add $LXD_CONTAINER mymount disk source=$PWD path=$MOUNT_POINT
fi

exec_container_root apt install -y debhelper
lxc file push $SCRIPT_DIR/$CREATE_REPO_SCRIPT $LXD_CONTAINER$USERDIR/
exec_container [ -x debian/bileto_pre_release_hook ] && ./debian/bileto_pre_release_hook

# install build dependencies in container
exec_container test -e $USERDIR/dependencies_installed
DEPS_INSTALLED=$?
if [ $DEPS_INSTALLED -ne 0 ] ; then
    exec_container dpkg-buildpackage -S -nc
    exec_container $USERDIR/$CREATE_REPO_SCRIPT $USERDIR
    exec_container_root add-apt-repository --enable-source \"deb file://$USERDIR/ /\"
    exec_container_root apt update
    exec_container_root apt-get build-dep -y -a$TARGET_ARCH $PACKAGE
    if [ $? -ne 0 ] ; then exit; fi;
    exec_container touch $USERDIR/dependencies_installed
fi;

# crossbuild package in container
exec_container rm ../*.deb
exec_container rm debian/*.debhelper.log
exec_container cp debian/changelog debian/changelog.orig
exec_container dch -v $NEW_PACKAGE_VERSION \'\'
exec_container DEB_BUILD_OPTIONS=parallel=$PARALLEL_BUILD dpkg-buildpackage -a$TARGET_ARCH -us -uc -nc
exec_container mv debian/changelog.orig debian/changelog
if [ $? -ne 0 ] ; then exit; fi;

# transfer resulting debian packages to local machine
exec_container tar cf ../$DEBS_TARBALL ../*.deb
lxc file pull $LXD_CONTAINER$USERDIR/$DEBS_TARBALL .

# tranfer debian packages to device
exec_device "printf '#\041/bin/sh\necho $DEVICE_PASSWORD' >/tmp/askpass.sh"
exec_device chmod +x /tmp/askpass.sh
exec_device SUDO_ASKPASS=/tmp/askpass.sh sudo -A mount -o remount,rw /
exec_device mkdir /tmp/repo
adb push $DEBS_TARBALL /tmp/repo/
exec_device "cd /tmp/repo && tar xvf /tmp/repo/$DEBS_TARBALL && rm /tmp/repo/$DEBS_TARBALL"

if [ -z "$PACKAGES_TO_DEPLOY" ] ; then
    echo "Installing manually specified packages:" $PACKAGES_TO_DEPLOY
    for package in $PACKAGES_TO_DEPLOY ; do
        exec_device SUDO_ASKPASS=/tmp/askpass.sh sudo -A dpkg -i '/tmp/repo/'$package'_'$NEW_PACKAGE_VERSION'_'$TARGET_ARCH'.deb'
    done
else
    # create local deb repository on device
    exec_device test -e /tmp/repo/$CREATE_REPO_SCRIPT
    REPO_SETUP=$?
    if [ $REPO_SETUP -ne 0 ] ; then
        adb push $SCRIPT_DIR/$CREATE_REPO_SCRIPT /tmp/repo/
        exec_device /tmp/repo/$CREATE_REPO_SCRIPT /tmp/repo
        exec_device SUDO_ASKPASS=/tmp/askpass.sh sudo -A add-apt-repository -y "deb file:///tmp/repo/ /"
        SERIES=$(adb shell lsb_release -cs | tr -d '\r')
        exec_device "printf 'Package: *\nPin: release o=local\nPin-Priority: 2000\n\nPackage: *\nPin: release a=$SERIES*\nPin-Priority: 50' | SUDO_ASKPASS=/tmp/askpass.sh sudo -A tee /etc/apt/preferences.d/localrepo.pref"
    fi;

    # install debian packages on device
    exec_device SUDO_ASKPASS=/tmp/askpass.sh sudo -A apt-get update
    exec_device SUDO_ASKPASS=/tmp/askpass.sh sudo -A apt-get dist-upgrade --yes --force-yes
fi;

