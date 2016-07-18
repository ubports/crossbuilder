#!/bin/sh
# This program is free software: you can redistribute it and/or modify it
# under the terms of the the GNU General Public License version 3, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranties of
# MERCHANTABILITY, SATISFACTORY QUALITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the applicable version of the GNU General Public
# License for more details.
#.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2014 Canonical, Ltd.

check_devices() {
    # Quick way to make sure that we fail gracefully if more than one device 
    # is connected and no serial is passed
    set +e
    adb wait-for-device
    err=$?
    set -e
    if [ $err != 0 ]; then
        echo "E: more than one device or emulator"
        adb devices
        exit 1
    fi
}
