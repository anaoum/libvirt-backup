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
