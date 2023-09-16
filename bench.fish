#!/usr/bin/env fish

# Cappy's sysbench kernel benchmarking script for Linux
# Written for Fyra Kernel development

# This script is designed to be run using the fish shell.
# if VERBOSE=yes, fish_trace is on
if test "$VERBOSE" = yes
    set fish_trace on
end

# full bench
set FULL_BENCH true

set kernel_version (uname -r)
# multiline echo

# if $SUITES exists, use that, otherswise use the default
if test -z "$SUITES"
    set SUITES fyra
end
# if STEAM=yes, add the steam suite
if test "$STEAM" = yes
    set -a SUITES fyra-steam
else if test "$STEAM" = false
    set -e SUITES fyra-steam
end

# if FULL_BENCH=true, add the full suite
if test "$FULL_BENCH" = true
    set SUITES fyra-full fyra-steam fyra
end


echo """
Fyra System Benchmark Tool
Written by Cappy Ishihara

The Kernel version is: $kernel_version
The suites to be run are: $SUITES
========================================
"""

# get kernel version


set -l rpm_packages \
    php-cli \
    php-xml \
    php-common \
    uuid-devel \
    libuuid-devel \
    gtest-devel \
    libaio-devel \
    php-pdo \
    google-benchmark-devel \
    snappy-devel \
    gcc-c++ \
    gcc \
    make \
    cmake \
    fish \
    wget \
    git \
    curl


function check_rpm
    # argument is the package name
    set pkg $argv[1]

    # echo "Checking for $pkg..."
    if test (rpm -q $pkg) = "package $pkg is not installed"
        set -a pkgs_to_install $pkg
    end

end

echo "Checking for required packages..."

for pkg in $rpm_packages
    # echo "Checking for $pkg..."
    check_rpm $pkg &
    wait
end

# if there are packages to install, install them

if test (count $pkgs_to_install) -gt 0
    echo "Installing packages..."
    sudo dnf install $pkgs_to_install
end



# hardware info function

function hardware_info
    echo "Hardware info:"
    lscpu | grep -E 'Model name|Socket|Thread|NUMA|CPU\(s\)'
    echo ""
end


function prepare_folders
    mkdir -p "results/$kernel_version/phoronix"
    # Install Test Suite
    mkdir -p ~/.phoronix-test-suite/test-suites/local
    # ln -sfv "$PWD/suites/fyra" ~/.phoronix-test-suite/test-suites/local/
    for suite in $SUITES
        ln -sfv "$PWD/suites/$suite" ~/.phoronix-test-suite/test-suites/local/
    end

    # Install config
    ln -sfv "$PWD/user-config.xml" ~/.phoronix-test-suite/
end



# Phoronix Test Suite benchmarks
set psuite ./phoronix-test-suite/phoronix-test-suite

set -x OUTPUT_DIR "$PWD/results/$kernel_version/phoronix"
set -x TEST_RESULTS_NAME "fyrabench-$kernel_version"
set -x MONITOR all
set -x LINUX_PERF TRUE

# Normalize the test result name, without ., replace spaces with dashes, and lowercase, remove _

set FINAL_TEST_RESULTS_NAME (echo $TEST_RESULTS_NAME | tr -d '.' | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | tr -d '_')
function psuite_tests
    $psuite batch-benchmark $SUITES
end


function export_px
    echo "Dumping Raw report data..."
    set -x OUTPUT_DIR "$PWD/results/$kernel_version/phoronix"
    rsync -a ~/.phoronix-test-suite/test-results/$FINAL_TEST_RESULTS_NAME/ $OUTPUT_DIR/$FINAL_TEST_RESULTS_NAME

    echo "Exporting Phoronix Test Suite results..."
    set -x OUTPUT_DIR "$PWD/results/$kernel_version/phoronix/exports"
    mkdir -p $OUTPUT_DIR
    $psuite result-file-to-csv $FINAL_TEST_RESULTS_NAME >/dev/null &
    $psuite result-file-to-html $FINAL_TEST_RESULTS_NAME >/dev/null &
    $psuite result-file-to-json $FINAL_TEST_RESULTS_NAME >/dev/null &
    $psuite result-file-to-pdf $FINAL_TEST_RESULTS_NAME >/dev/null &
    $psuite result-file-to-text $FINAL_TEST_RESULTS_NAME >/dev/null &

    # wait for all the above to finish
    wait

end

function start_benchmarks
    echo "Starting benchmarks..."
    echo "Deleting old results..."
    # rm -rf "results/$kernel_version"
    prepare_folders
    echo "Running Phoronix Test Suite benchmarks..."
    psuite_tests
    # export_px
end

start_benchmarks
