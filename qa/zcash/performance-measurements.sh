#!/bin/bash
set -u


DATADIR=./benchmark-datadir
SHA256CMD="$(command -v sha256sum || echo shasum)"
SHA256ARGS="$(command -v sha256sum >/dev/null || echo '-a 256')"

function mlgb_rpc {
    ./src/mlgb-cli -datadir="$DATADIR" -rpcuser=user -rpcpassword=password -rpcport=5983 "$@"
}

function mlgb_rpc_slow {
    # Timeout of 1 hour
    mlgb_rpc -rpcclienttimeout=3600 "$@"
}

function mlgb_rpc_veryslow {
    # Timeout of 2.5 hours
    mlgb_rpc -rpcclienttimeout=9000 "$@"
}

function mlgb_rpc_wait_for_start {
    mlgb_rpc -rpcwait getinfo > /dev/null
}

function mlgbd_generate {
    mlgb_rpc generate 101 > /dev/null
}

function mlgbd_start {
    rm -rf "$DATADIR"
    mkdir -p "$DATADIR/regtest"
    touch "$DATADIR/mlgb.conf"
    ./src/mlgbd -regtest -datadir="$DATADIR" -rpcuser=user -rpcpassword=password -rpcport=5983 -showmetrics=0 &
    ZCASHD_PID=$!
    mlgb_rpc_wait_for_start
}

function mlgbd_stop {
    mlgb_rpc stop > /dev/null
    wait $ZCASHD_PID
}

function mlgbd_massif_start {
    rm -rf "$DATADIR"
    mkdir -p "$DATADIR/regtest"
    touch "$DATADIR/mlgb.conf"
    rm -f massif.out
    valgrind --tool=massif --time-unit=ms --massif-out-file=massif.out ./src/mlgbd -regtest -datadir="$DATADIR" -rpcuser=user -rpcpassword=password -rpcport=5983 -showmetrics=0 &
    ZCASHD_PID=$!
    mlgb_rpc_wait_for_start
}

function mlgbd_massif_stop {
    mlgb_rpc stop > /dev/null
    wait $ZCASHD_PID
    ms_print massif.out
}

function mlgbd_valgrind_start {
    rm -rf "$DATADIR"
    mkdir -p "$DATADIR/regtest"
    touch "$DATADIR/mlgb.conf"
    rm -f valgrind.out
    valgrind --leak-check=yes -v --error-limit=no --log-file="valgrind.out" ./src/mlgbd -regtest -datadir="$DATADIR" -rpcuser=user -rpcpassword=password -rpcport=5983 -showmetrics=0 &
    ZCASHD_PID=$!
    mlgb_rpc_wait_for_start
}

function mlgbd_valgrind_stop {
    mlgb_rpc stop > /dev/null
    wait $ZCASHD_PID
    cat valgrind.out
}

function extract_benchmark_data {
    if [ -f "block-107134.tar.xz" ]; then
        # Check the hash of the archive:
        "$SHA256CMD" $SHA256ARGS -c <<EOF
4bd5ad1149714394e8895fa536725ed5d6c32c99812b962bfa73f03b5ffad4bb  block-107134.tar.xz
EOF
        ARCHIVE_RESULT=$?
    else
        echo "block-107134.tar.xz not found."
        ARCHIVE_RESULT=1
    fi
    if [ $ARCHIVE_RESULT -ne 0 ]; then
        mlgbd_stop
        echo
        echo "Please generate it using qa/mlgb/create_benchmark_archive.py"
        echo "and place it in the base directory of the repository."
        echo "Usage details are inside the Python script."
        exit 1
    fi
    xzcat block-107134.tar.xz | tar x -C "$DATADIR/regtest"
}

# Precomputation
case "$1" in
    *)
        case "$2" in
            verifyjoinsplit)
                mlgbd_start
                RAWJOINSPLIT=$(mlgb_rpc zcsamplejoinsplit)
                mlgbd_stop
        esac
esac

case "$1" in
    time)
        mlgbd_start
        case "$2" in
            sleep)
                mlgb_rpc zcbenchmark sleep 10
                ;;
            parameterloading)
                mlgb_rpc zcbenchmark parameterloading 10
                ;;
            createjoinsplit)
                mlgb_rpc zcbenchmark createjoinsplit 10 "${@:3}"
                ;;
            verifyjoinsplit)
                mlgb_rpc zcbenchmark verifyjoinsplit 1000 "\"$RAWJOINSPLIT\""
                ;;
            solveequihash)
                mlgb_rpc_slow zcbenchmark solveequihash 50 "${@:3}"
                ;;
            verifyequihash)
                mlgb_rpc zcbenchmark verifyequihash 1000
                ;;
            validatelargetx)
                mlgb_rpc zcbenchmark validatelargetx 5
                ;;
            trydecryptnotes)
                mlgb_rpc zcbenchmark trydecryptnotes 1000 "${@:3}"
                ;;
            incnotewitnesses)
                mlgb_rpc zcbenchmark incnotewitnesses 100 "${@:3}"
                ;;
            connectblockslow)
                extract_benchmark_data
                mlgb_rpc zcbenchmark connectblockslow 10
                ;;
            *)
                mlgbd_stop
                echo "Bad arguments."
                exit 1
        esac
        mlgbd_stop
        ;;
    memory)
        mlgbd_massif_start
        case "$2" in
            sleep)
                mlgb_rpc zcbenchmark sleep 1
                ;;
            parameterloading)
                mlgb_rpc zcbenchmark parameterloading 1
                ;;
            createjoinsplit)
                mlgb_rpc_slow zcbenchmark createjoinsplit 1 "${@:3}"
                ;;
            verifyjoinsplit)
                mlgb_rpc zcbenchmark verifyjoinsplit 1 "\"$RAWJOINSPLIT\""
                ;;
            solveequihash)
                mlgb_rpc_slow zcbenchmark solveequihash 1 "${@:3}"
                ;;
            verifyequihash)
                mlgb_rpc zcbenchmark verifyequihash 1
                ;;
            trydecryptnotes)
                mlgb_rpc zcbenchmark trydecryptnotes 1 "${@:3}"
                ;;
            incnotewitnesses)
                mlgb_rpc zcbenchmark incnotewitnesses 1 "${@:3}"
                ;;
            connectblockslow)
                extract_benchmark_data
                mlgb_rpc zcbenchmark connectblockslow 1
                ;;
            *)
                mlgbd_massif_stop
                echo "Bad arguments."
                exit 1
        esac
        mlgbd_massif_stop
        rm -f massif.out
        ;;
    valgrind)
        mlgbd_valgrind_start
        case "$2" in
            sleep)
                mlgb_rpc zcbenchmark sleep 1
                ;;
            parameterloading)
                mlgb_rpc zcbenchmark parameterloading 1
                ;;
            createjoinsplit)
                mlgb_rpc_veryslow zcbenchmark createjoinsplit 1 "${@:3}"
                ;;
            verifyjoinsplit)
                mlgb_rpc zcbenchmark verifyjoinsplit 1 "\"$RAWJOINSPLIT\""
                ;;
            solveequihash)
                mlgb_rpc_veryslow zcbenchmark solveequihash 1 "${@:3}"
                ;;
            verifyequihash)
                mlgb_rpc zcbenchmark verifyequihash 1
                ;;
            trydecryptnotes)
                mlgb_rpc zcbenchmark trydecryptnotes 1 "${@:3}"
                ;;
            incnotewitnesses)
                mlgb_rpc zcbenchmark incnotewitnesses 1 "${@:3}"
                ;;
            connectblockslow)
                extract_benchmark_data
                mlgb_rpc zcbenchmark connectblockslow 1
                ;;
            *)
                mlgbd_valgrind_stop
                echo "Bad arguments."
                exit 1
        esac
        mlgbd_valgrind_stop
        rm -f valgrind.out
        ;;
    valgrind-tests)
        case "$2" in
            gtest)
                rm -f valgrind.out
                valgrind --leak-check=yes -v --error-limit=no --log-file="valgrind.out" ./src/mlgb-gtest
                cat valgrind.out
                rm -f valgrind.out
                ;;
            test_bitcoin)
                rm -f valgrind.out
                valgrind --leak-check=yes -v --error-limit=no --log-file="valgrind.out" ./src/test/test_bitcoin
                cat valgrind.out
                rm -f valgrind.out
                ;;
            *)
                echo "Bad arguments."
                exit 1
        esac
        ;;
    *)
        echo "Bad arguments."
        exit 1
esac

# Cleanup
rm -rf "$DATADIR"
