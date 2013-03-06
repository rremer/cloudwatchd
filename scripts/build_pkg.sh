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

    # Make the packaging dir and copy distro-agnostic files
    mkdir cloudwatchd
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
            MANIFEST_OUT='cloudwatchd/DEBIAN/control'
            mkdir -p cloudwatchd/DEBIAN
            cp -r ../deb/control/* cloudwatchd/DEBIAN/
            buildManifest
            chmod -R 0755 cloudwatchd/DEBIAN
            cd cloudwatchd
            find . -type f | xargs md5sum | \
            sed -e 's_  _ /_g' | \
            grep -v "\/DEBIAN\/" > ../DEBIAN/md5sums
            cd ..
            sudo dpkg-deb --build cloudwatchd
    elif [ "$PKG" = "rpm" ]
        then
            MANIFEST_OUT='SPEC/cloudwatchd.spec'
            cp -r ../rpm/* cloudwatchd/
            mkdir -p cloudwatchd/usr/local
            mv cloudwatchd/bin cloudwatchd/usr/local/
            chmod -R 755 cloudwatchd/usr/local/bin
            mv cloudwatchd/SPEC .
            buildManifest
            if [ "$EXEC_PATH" = '.' ]
                then BUILDROOT="$(pwd)/cloudwatchd"
                else BUILDROOT="$EXEC_PATH/cloudwatchd"
            fi
            sudo rpmbuild -bb $MANIFEST_OUT --buildroot $BUILDROOT --define "_rpmdir ."
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

buildManifest() {
    # Replace manifest values surround by '%' control character from template
    # I would do this with pyaml, but not everyone has that installed.
    MANIFEST_TEMPLATE="../version.yaml"

    for value in $(awk -F"!" '{print $2}' "$MANIFEST_OUT")
        do
            template_value=$(awk -F"$value" '{printf $2}' "$MANIFEST_TEMPLATE" |\
            awk -F": " '{printf $2}')
            if [ "$PKG" = 'deb' ]
                then true
                # deb control file descriptions need to be indented
                if [ "$value" = 'Description' ]
                    then template_value="  $template_value"
                fi
            elif [ "$PKG" = 'rpm' ]
                then true
                if [ "$value" = 'RPMFiles' ]
                    then
                        cd cloudwatchd
                        find . -type f |\
                        sed -e 's_  __g' > ../rpmfiles.tmp
                        cd ..
                        sed -i -e's_\./_/_g' rpmfiles.tmp
                        sed -i -e's_%files__g' "$MANIFEST_OUT"
                        sed -i -e's_'!"$value"!'_d' "$MANIFEST_OUT"
                        echo '%files' >> "$MANIFEST_OUT"
                        cat rpmfiles.tmp >> "$MANIFEST_OUT"
                fi
            fi
            if [ -z "$template_value" ]
                then template_value=" "
            fi
            sed -i -e's_'\!"$value"\!'_'"$template_value"'_g' "$MANIFEST_OUT"
        done
}

setup
build
teardown
exit 0
