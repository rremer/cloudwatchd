#!/bin/sh
#
# Build a binary archive of cloudwatchd

case "$1" in
    deb|--deb)
    PKG="deb"
    ;;
    rpm|--deb)
    PKG="rpm"
    ;;
    help|-h|--help)
    echo "\
    deb, --deb               build a .deb\n
    rpm, --rpm               build a .rpm\n
    version, -v, --version   print program version\n
    help, -h, --help         print this usage message"
    ;;
    *)
    echo "$1 is not an option."
    $0 help
    ;;
esac

setup() {
    # Assert path local
    ORIGWD=$PWD
    EXEC_PATH=$(dirname $0)
    cd $EXEC_PATH

    # Make the packaging dir and copy distro-specific files
    mkdir -p cloudwatchd/DEBIAN
    cp -r ../$PKG/control/* cloudwatchd/DEBIAN/
    chmod -R 0755 cloudwatchd/DEBIAN
    mkdir -p cloudwatchd/etc/init.d
    cp ../cloudwatchd.init cloudwatchd/etc/init.d/cloudwatchd
    mkdir cloudwatchd/etc/cloudwatchd
    cp ../*.conf cloudwatchd/etc/cloudwatchd/
    mkdir -p cloudwatchd/usr/sbin
    cp ../cloudwatchd-worker.py cloudwatchd/usr/sbin/cloudwatchd-worker
    # Copy MANPAGEs, identified by a title line
    for MANPAGE in $(grep ".TH" ../docs/* | cut -d ':' -f 1 | uniq)
        do
            MANPATH=cloudwatchd/usr/share/man/man$(echo $MANPAGE | cut -d "." -f 4)
            if [ -d "$MANPATH" ]
                then true
                else mkdir -p $MANPATH
            fi
            cp $MANPAGE $MANPATH/
        done
}

build() {
    echo "[INFO]: Building $PKG package in $ORIGWD, this will require root privileges."
    if [ "$PKG" = "deb" ]
        then
            find cloudwatchd/ -type f | xargs md5sum | sed -e 's/cloudwatchd\///g' | sed -e 's/  / \//g' | grep -v "\/DEBIAN\/" > cloudwatchd/DEBIAN/md5sums
            sudo dpkg-deb --build cloudwatchd
    elif [ "$PKG" = "rpm" ]
        then
            sudo rpmbuild -bb cloudwatchd
    else
        echo "$PKG is not a valid build option, exiting."
        exit 1
    fi

    if [ "$EXEC_PATH" != "." ]
        then mv cloudwatchd.$PKG $ORIGWD
    fi
}

teardown() {
    cd $ORIGWD
    echo "[INFO]: $EXEC_PATH/cloudwatchd directory may be deleted, but kept if you want\
 to manually build with extra files."
}

setup
build
teardown
exit 0
