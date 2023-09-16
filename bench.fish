#!/usr/bin/env fish

# Cappy's sysbench kernel benchmarking script for Linux
# Written for Fyra Kernel development

# This script is designed to be run using the fish shell.



# get kernel version

set kernel_version (uname -r)


echo "Kernel version: $kernel_version"


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
    ln -sfv "$PWD/fyra" ~/.phoronix-test-suite/test-suites/local/
end


function sysbench_mem
    echo "Running sysbench memory benchmark..."
    sysbench memory --threads=$(nproc) run
    echo "Done."
end

function sysbench_cpu
    echo "Running sysbench CPU benchmark..."
    sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) run
    echo "Done."
end

function sysbench_io
    echo "Running sysbench IO benchmark..."
    mkdir -p tmp
    pushd tmp
    sysbench fileio --file-test-mode=seqwr run
    echo "Done."

    echo "Cleaning up..."

    sysbench fileio --file-total-size=100G cleanup
    popd
end

function sysbench_threads
    echo "Running sysbench threads benchmark..."
    sysbench threads --threads=64 --thread-yields=1000 --thread-locks=4 run
    echo "Done."
end

function sysbench_mutex
    echo "Running sysbench mutex benchmark..."
    sysbench mutex --threads=$(nproc) run
    echo "Done."
end


# Phoronix Test Suite benchmarks
set psuite ./phoronix-test-suite/phoronix-test-suite

set -x OUTPUT_DIR "$PWD/results/$kernel_version/phoronix"
# set -x OUTPUT_FILE "$PWD/results/$kernel_version/phoronix/cappybench"
set -x TEST_RESULTS_NAME "cappybench-$kernel_version"
set -x MONITOR all
set -x LINUX_PERF TRUE

# Normalize the test result name, without ., replace spaces with dashes, and lowercase, remove _

set FINAL_TEST_RESULTS_NAME (echo $TEST_RESULTS_NAME | tr -d '.' | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | tr -d '_')
function psuite_tests
    set -x OUTPUT_DIR "$PWD/results/$kernel_version/phoronix"
    $psuite batch-benchmark fyra
end


function export_px
    echo "Dumping Raw report data..."
    set -x OUTPUT_DIR "$PWD/results/$kernel_version/phoronix"
    rsync -a ~/.phoronix-test-suite/test-results/$FINAL_TEST_RESULTS_NAME/ $OUTPUT_DIR/$FINAL_TEST_RESULTS_NAME

    echo "Exporting Phoronix Test Suite results..."
    set -x OUTPUT_DIR "$PWD/results/$kernel_version/phoronix/exports"
    mkdir -p $OUTPUT_DIR
    $psuite result-file-to-csv $FINAL_TEST_RESULTS_NAME > /dev/null &
    $psuite result-file-to-html $FINAL_TEST_RESULTS_NAME > /dev/null &
    $psuite result-file-to-json $FINAL_TEST_RESULTS_NAME > /dev/null &
    $psuite result-file-to-pdf $FINAL_TEST_RESULTS_NAME > /dev/null &
    $psuite result-file-to-text $FINAL_TEST_RESULTS_NAME > /dev/null &

    # wait for all the above to finish
    wait

end

function start_benchmarks
    echo "Starting benchmarks..."
    echo "Deleting old results..."
    # rm -rf "results/$kernel_version"
    prepare_folders
    hardware_info > "results/$kernel_version/hardware_info.txt"
    sysbench_threads > tee "results/$kernel_version/sysbench_threads.txt"
    sysbench_mutex > tee "results/$kernel_version/sysbench_mutex.txt"
    sysbench_io > tee "$PWD/results/$kernel_version/sysbench_io.txt"
    echo "==========================="
    echo "SYSBENCH BENCHMARKS COMPLETE"
    echo "==========================="
    echo ""
    echo "Running Phoronix Test Suite benchmarks..."
    psuite_tests
    export_px
end

start_benchmarks
