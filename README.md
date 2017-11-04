# crossbuilder
A debian package cross building tool using LXD

Crossbuilder aims at making cross compiling code and deploying projects to devices simple, reliable and most importantly fast. It uses LXD containers and ccache by default.

Initially developed in: https://launchpad.net/crossbuilder

To use it, clone the repository and just run it from there:

    cd crossbuilder
    ./crossbuilder help

To build and deploy your project on the device connected to your computer all in one go:

    cd yourproject/
    crossbuilder

Change a line of code and type crossbuilder again to re-build and re-deploy.

To go even faster, bypass building Debian packages with:

    crossbuilder --no-deb

For an even faster LXD setup, resetup LXD using ZFS:

    crossbuilder setup-lxd

To enter the LXD container used to build:

    crossbuilder shell
