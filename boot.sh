#!/usr/bin/env bash

default_library_name='shtdlib.sh'
default_base_download_url='https://raw.githubusercontent.com/sdelements/shtdlib/master'
default_install_path='/usr/local/bin'

# Temporary debug function
type -t import | grep -q '^function$' || function debug { echo "${@:2}" ; }

# Import or source
function import_or_source {
    if type -t import | grep -q '^function$' ; then
        debug 10 "Importing ${1}"
        import "${1}"
    else
        debug 10 "Sourcing ${1}"
        # shellcheck disable=1090
        source "${1}"
    fi
}

# Library download function, optionally accepts a full path/name and URL
function download_lib {
    local tmp_path="${1:-$(mktemp)}"
    local lib_url="${2:-${default_base_download_url}/${default_library_name}}"
    curl -s -l -o "${tmp_path}" "${lib_url}" || wget --no-verbose "${lib_url}" --output-document "${tmp_path}" || return 1
}

# Library install function, optionallly accepts a URL and a full path/name
# shellcheck disable=SC2120,SC2119
function install_lib {
    local lib_path="${1:-${default_install_path}/${default_library_name}}"
    local lib_name="${2:-$(basename "${lib_path}")}"
    local tmp_path="${3:-$(mktemp)}"

    echo "Installing library ${lib_name} to ${lib_path}"
    download_lib "${tmp_path}" "${default_base_download_url}/${lib_name}"
    mv "${tmp_path}" "${lib_path}" || sudo mv "${tmp_path}" "${lib_path}" || return 1
    chmod 755 "${lib_path}" || sudo chmod 755 "${lib_path}" || return 1
    import_or_source "${lib_path}"
    color_echo green "Installed ${lib_name} to ${lib_path} successfully"
}

# Library import function, accepts one optional parameter, name of the file to import
# shellcheck disable=SC2120,SC2119
function import_lib {
    local full_path
    local lib_name="${1:-${default_library_name}}"
    local lib_no_ext="${lib_name%.*}"
    local lib_basename_s="${lib_no_ext##*/}"
    full_path="$(readlink -f "${BASH_SOURCE[0]}" 2> /dev/null || realpath "${BASH_SOURCE[0]}" 2> /dev/null || greadlink -f "${BASH_SOURCE[0]}" 2> /dev/null || true)"
    full_path="${full_path:-${0}}"
    # Search current dir and walk down to see if we can find the library in a
    # parent directory or sub directories of parent directories named lib/bin
    while true; do
        local pref_pattern=( "${full_path}/${lib_name}" "${full_path}/${lib_basename_s}/${lib_name}" "${full_path}/lib/${lib_name}" "${full_path}/bin/${lib_name}" )
        for pref_lib in "${pref_pattern[@]}" ; do
            if [ -e "${pref_lib}" ] ; then
                debug 10 "Found ${pref_lib}, attempting to import/source"
                import_or_source "${pref_lib}" && return 0
                echo "Unable to import/source ${pref_lib}!"
            fi
        done
        full_path="$(dirname "${full_path}")"
        if [ "${full_path}" == '/' ] ; then
            # If we haven't found the library try the PATH or install if needed
            debug 10 "Attempting to import/source ${lib_name}"
            import_or_source "${lib_name}" 2> /dev/null || install_lib "${default_install_path}/${lib_name}" "${lib_name}" && return 0
            # If nothing works then we fail
            echo "Unable to import ${lib_name}"
            return 1
        fi
    done
}

# Import the shell standard library
# shellcheck disable=SC2119
import_lib

code_name='Mojave'
options="+pcid,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check"

qemu-system-x86_64 -enable-kvm -m 3072 -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,${options}\
	  -machine pc-q35-2.11 \
	  -smp 4,cores=2 \
	  -usb -device usb-kbd -device usb-tablet \
	  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
	  -drive if=pflash,format=raw,readonly,file=OVMF_CODE.fd \
	  -drive if=pflash,format=raw,file=OVMF_VARS-1024x768.fd \
	  -smbios type=2 \
	  -device ich9-intel-hda -device hda-duplex \
	  -device ide-drive,bus=ide.2,drive=Clover \
	  -drive id=Clover,if=none,snapshot=on,format=qcow2,file="./Clover.qcow2" \
	  -device ide-drive,bus=ide.1,drive=MacHDD \
	  -drive id=MacHDD,if=none,file=./mac_hdd.img,format=qcow2 \
	  -device ide-drive,bus=ide.0,drive=MacDVD \
	  -drive id=MacDVD,if=none,snapshot=on,media=cdrom,file=./"${code_name}.iso" \
	  -netdev tap,id=net0,ifname=tap0,script=no,downscript=no -device vmxnet3,netdev=net0,id=net0,mac=52:54:00:c9:18:27 \
	  -monitor stdio
