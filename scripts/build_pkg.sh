#!/bin/sh
#
# Build a binary archive of cloudwatchd... super hacky to support both rpm, deb,
# and potentially other formats. Inspiring commits to alien to accept special
# scriptable arguments
# TODO: refactor to a function per special file... would make more sense

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
    mkdir -p cloudwatchd/etc/init.d
    chmod -R 0755 cloudwatchd
    cp ../cloudwatchd.init cloudwatchd/etc/init.d/cloudwatchd
    chmod -R 0755 cloudwatchd/etc/init.d
    mkdir -m 0755 cloudwatchd/etc/cloudwatchd
    cp ../*.conf cloudwatchd/etc/cloudwatchd/
    chmod 0644 cloudwatchd/etc/cloudwatchd/*
    mkdir -m 0755 -p cloudwatchd/usr/sbin
    chmod 0755 cloudwatchd/usr
    cp ../cloudwatchd-worker.py cloudwatchd/usr/sbin/cloudwatchd-worker
    chmod -R 0755 cloudwatchd/usr/sbin
    cp -r ../metrics cloudwatchd/etc/cloudwatchd/
    chmod -R 0755 cloudwatchd/etc/cloudwatchd/metrics
    mkdir -p cloudwatchd/usr/share/doc/cloudwatchd
    chmod -R 0755 cloudwatchd/usr/share
    cp ../copyright cloudwatchd/usr/share/doc/cloudwatchd/
    chmod 0644 cloudwatchd/usr/share/doc/cloudwatchd/copyright
    # Copy MANPAGEs, identified by a title line
    for MANPAGE in $(grep ".TH" ../docs/* | cut -d ':' -f 1 | uniq)
        do
            MANPATH=cloudwatchd/usr/share/man/man$(echo $MANPAGE | cut -d "." -f 4)
            if [ -d "$MANPATH" ]
                then true
                else mkdir -p $MANPATH
            fi
            cp $MANPAGE $MANPATH/
            single_manpath="$MANPATH/$(echo $MANPAGE | sed 's_../docs/__g')"
            gzip -9 $single_manpath
            chmod 644 $single_manpath*
        done
}

build() {
    echo "[INFO]: Building $PKG package in $ORIGWD"
    if [ "$PKG" = "deb" ]
        then
            MANIFEST_OUT='cloudwatchd/DEBIAN/control'
            mkdir -p cloudwatchd/DEBIAN
            cp -r ../deb/control/* cloudwatchd/DEBIAN/
            chmod 644 cloudwatchd/DEBIAN/control
            buildManifest
            chmod -R 0755 cloudwatchd/DEBIAN
            # Generate the changelog
            changelog=cloudwatchd/usr/share/doc/cloudwatchd/changelog
            template_urgency=$(awk -F"Urgency" '{printf $2}' "$MANIFEST_TEMPLATE" |\
            awk -F": " '{printf $2}')
            template_version=$(awk -F"Version" '{printf $2}' "$MANIFEST_TEMPLATE" |\
            awk -F": " '{printf $2}')
            template_changelog=$(awk -F"Changelog" '{printf $2}' "$MANIFEST_TEMPLATE" |\
            awk -F": " '{printf $2}')
            template_maintainer=$(awk -F"Maintainer" '{printf $2}' "$MANIFEST_TEMPLATE" |\
            awk -F": " '{printf $2}')
            echo "cloudwatchd ($template_version); urgency=$template_urgency" > "$changelog"
            echo "$template_changelog" >> "$changelog"
            timedate=$(date +"%a, %d %b %Y %H:%M:%S %z")
            echo "$template_maintainer  $timedate" >> "$changelog"
            gzip -9 "$changelog"
            chmod 0644 "$changelog".gz
            # Generate the md5sums file
            cd cloudwatchd
            find . -type f | xargs md5sum | \
            sed -e 's_  ./_ _g' | \
            grep -v "DEBIAN\/" > DEBIAN/md5sums
            chmod 644 DEBIAN/md5sums
            # Generate the conffiles
            cd etc
            find . -type f |\
            sed -e 's_\./_/etc/_g' > ../DEBIAN/conffiles
            chmod 644 ../DEBIAN/conffiles
            # Get back to the scripts dir
            cd ../..
            # Build the deb
            sudo chown -R root:root cloudwatchd
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
            # Build the rpm
            sudo chown -R root:root cloudwatchd
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
    if [ "$PKG" = 'deb' ]
        then sudo rm -r $EXEC_PATH/cloudwatchd
    elif [ "$PKG" = 'rpm' ]
        then sudo rm -rf $EXEC_PATH/SPEC
    fi
}

buildManifest() {
    # Replace manifest values surround by '%' control character from template
    # I would do this with pyaml, but not everyone has that installed.
    MANIFEST_TEMPLATE="../version.yaml"

    for value in $(awk -F'!' '{print $2}' "$MANIFEST_OUT")
        do
            template_value=$(awk -F"$value" '{printf $2}' "$MANIFEST_TEMPLATE" |\
            awk -F": " '{printf $2}')
            if [ "$PKG" = 'deb' ]
                then true
                # make control description lines indented and < 80 chars
                if [ "$value" = 'Description' ]
                    then
                        echo "$template_value" > .description.tmp
                        fold -w 80 -s .description.tmp > .description.tmp.2
                        sed -i 's/^/ /g' .description.tmp.2
                        sed -i '/\!Description\!/d' "$MANIFEST_OUT"
                        cat .description.tmp.2 >> "$MANIFEST_OUT"
                        rm .description.tmp*
                fi
            elif [ "$PKG" = 'rpm' ]
                then
                if [ "$value" = 'RPMFiles' ]
                    then true
                        # Find all files in package dir and dump to a file
                        cd cloudwatchd
                        find . -type f |\
                        sed -e 's_  __g' > ../rpmfiles.tmp
                        cd ..
                        # Set paths to fixed, from relative
                        sed -i -e's_\./_/_g' rpmfiles.tmp
                        # Remove the %files tag from wherever it is in the doc
                        # so we can *append* all files
                        sed -i -e's_%files__g' "$MANIFEST_OUT"
                        # Remove the tag, the final sed does nothing this round
                        sed -i -e'/\!RPMFiles\!/d' "$MANIFEST_OUT"
                        # Append the files tag and dump all paths after it
                        echo '%files' >> "$MANIFEST_OUT"
                        cat rpmfiles.tmp >> "$MANIFEST_OUT"
                        rm rpmfiles.tmp
                fi
                if [ "$value" = 'Depends' ]
                    then
                        # Separate comma-delimeted depencies onto lines
                        echo $template_value | sed 's/, /\n/g' > rpmdepends.tmp
                        # TODO:Deal with how to identify isa/noarch
                        #sed -i 's/$/\%\{\?_isa}/g' rpmdepends.tmp
                        # Append noarch to each dependency
                        sed -i 's/$/.noarch/g' rpmdepends.tmp
                        # Put all depencies back onto one line
                        template_value=$(sed ':a;N;s/\n/, /g' rpmdepends.tmp)
                        rm rpmdepends.tmp
                fi
            fi
            if [ -z "$template_value" ]
                then template_value=" "
            fi
            # Replace each tagged entry with the matching entry in version.yaml
            # Note: finding a control character not used in the templates is hard
            sed -i -e's~'\!"$value"\!'~'"$template_value"'~g' "$MANIFEST_OUT"
        done

        # Per-package finishing options
        if [ "$PKG" = 'rpm' ]
            then
                # Append the installation scripts to the manifest
                for script in `ls cloudwatchd/build`
                    do
                        echo %"$script" >> "$MANIFEST_OUT"
                        cat cloudwatchd/build/$script >> "$MANIFEST_OUT"
                    done
                # Clean up the spec spacing
                cat $MANIFEST_OUT | tr -s '\n' > $MANIFEST_OUT.2
                mv $MANIFEST_OUT.2 $MANIFEST_OUT
                sed -i 's/%/\n%/g' "$MANIFEST_OUT"
        fi
}

setup
build
teardown
exit 0
