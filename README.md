# crossbuilder
A debian package cross building tool using LXD

Crossbuilder aims at making cross compiling code and deploying projects to devices simple, reliable and most importantly fast. It uses LXD containers and ccache by default.

Initially developed in: https://launchpad.net/crossbuilder

To use it, clone the repository and just run it from there:
```bash
cd crossbuilder
./crossbuilder help
```

To build and deploy your project on the device connected to your computer all in one go:
```bash
cd yourproject/
crossbuilder
```

Crossbuilder by default builds for armhf architecture. If a device is connected, it should detect the devices architecture. In case for some reason the architecture needs to be explicitely specified, it can be set like this:
```bash
crossbuilder --architecture=arm64
```

To be able to install the deb on the device after building, the devices sudo password needs to be provided:
```bash
crossbuilder --password=PASSWORD
```
We can specify specific lxd images for the build process. This can be useful e.g. when building for specific target releases like 20.04. 
```bash
crossbuilder --lxd-image=ubuntu:20.04
```

Change a line of code and type crossbuilder again to re-build and re-deploy.

To go even faster, bypass building Debian packages with:
```bash
crossbuilder --no-deb
```

For an even faster LXD setup, resetup LXD using ZFS:
```bash
crossbuilder setup-lxd
```

To enter the LXD container used to build:
```bash
crossbuilder shell
```

To use ssh instead of adb to deploy, use the ```--ssh``` option. If your device has ssh enabled on address let's say 192.168.0.5, use:
```bash
crossbuilder --ssh=phablet@192.168.0.5
```
