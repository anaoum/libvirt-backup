#!/bin/bash

function get_backing_chain {
    qemu-img info --backing-chain "$1" | grep '^image:' | sed 's/^image:\s*//'
}
function get_backings {
    get_backing_chain "$1" | tail -n +2
}
function get_base {
    get_backing_chain "$1" | tail -1
}
function get_backing {
    get_backings "$1" | head -1
}
function has_backing {
    qemu-img info "$1" | grep -q '^backing file:'
}
function get_disks {
    virsh domblklist "$1" --details | grep '^file' | grep -v '\scdrom\s' | awk '{print $4}'
}
function get_backing_chain_length {
    get_backing_chain "$1" | wc -l
}
function delete_snapshot_chain {
    get_backing_chain "$1" | head -n -1 | while read image; do
        echo "Deleting old snapshot "$image"."
        rm -f "$image"
    done
}
function verify_domain_exists {
    if ! virsh dominfo "$1" > /dev/null 2>&1; then
        >&2 echo "Domain '$1' does not exist."
        exit 100
    fi
}
function verify_domain_running {
    if ! virsh dominfo "$1" | grep -q 'State:\s*running'; then
        >&2 echo "Domain '$1' is not running."
        exit 101
    fi
}
function get_quiesce {
    if virsh domfsthaw "$1" >/dev/null 2>&1; then
        echo "--quiesce"
    fi
}
function get_diskspec {
    get_disks "$1" | while read disk; do
        echo -n "--diskspec "$disk",snapshot=external "
    done
}
