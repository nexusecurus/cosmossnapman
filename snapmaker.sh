#!/bin/bash

export TERM=xterm-256color

set -e
clear

SCRIPT_DIR=$(dirname "$(realpath "$0")")

LOG_DIR="$SCRIPT_DIR/logs"

if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

SNAP_LAST_LOG="$LOG_DIR/snapmkr-last.log"
SNAP_FULL_LOG="$LOG_DIR/snapmkr-full.log"

exec > >(tee -a "$SNAP_LAST_LOG") 2>&1


if [ ! -d "$SCRIPT_DIR/vars" ]; then
    echo -e "\n$SCRIPT_DIR/vars directory not found. Cannot continue.\n\nExiting..."
    exit 1
fi

REQUIREMENTS_FILE="$SCRIPT_DIR/vars/requirements.txt"

if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
    echo -e "\nThere are some missing dependencies.\n\n$REQUIREMENTS_FILE not found.\n\nExiting..."
    exit 1
fi

CHECK_COMMAND() {
    command -v "$1" >/dev/null 2>&1
}

INSTALL_COMMAND() {
    local package="$1"
    sudo apt-get update
    sudo apt-get install -y "$package"
}


while IFS= read -r dependency; do
    if [[ -n "$dependency" ]]; then
        if ! CHECK_COMMAND "$dependency"; then
            if INSTALL_COMMAND "$dependency"; then
                echo -e "\n$dependency installed successfully.\n"
            else
                echo -e "\nError: Failed to install $dependency.\n\nExiting..."
                exit 1
            fi
        fi
    fi
done < "$REQUIREMENTS_FILE"

echo -e "\nAll required dependencies are met."

source "$SCRIPT_DIR/vars/chains.conf"
source "$SCRIPT_DIR/vars/remote.conf"

ssh -i "$SSH_KEY" -p "$REMOTE_SSH_PORT" "$REMOTE_HOST" -o StrictHostKeyChecking=no "exit"

if [ $? -eq 0 ]; then
    echo -e "\nConnection test: $REMOTE_HOST is reachable and ready.\n\nProcceeding...\n\n"
else
    echo "\nConnection test: $REMOTE_HOST is not reachable.\n\nExiting..."
    exit 1
fi


SNAPSHOT_COUNT_FILE="$SCRIPT_DIR/.snapshot_count"

if [ ! -f "$SNAPSHOT_COUNT_FILE" ]; then
    echo 0 > "$SNAPSHOT_COUNT_FILE"
fi

JSON_TMP_DIR=$(mktemp -d "$SCRIPT_DIR/metrics-XXXXXXXXXXX")
JSON_FILE="$JSON_TMP_DIR/snap_metrics.json"
SNAP_TMP_DIR=$(mktemp -d "$SCRIPT_DIR/snapshots-XXXXXXXXXX")


export PATH="$HOME/go/bin:$PATH"

TOTAL_SNAPSHOTS=$(cat "$SNAPSHOT_COUNT_FILE")
START_TIME=$(date +%s)
TOTAL_CHAINS=$((${#CHAINS[@]}))
BLOCKCHAIN_DIR="$DEST_DIR/blockchains"
TOTAL_SIZE=0
GLOB_COUNT=0
JOB=1

CHECKS() {
    local CHAIN=$1
    local HOME_DIR=$2
    local STATE_SYNC_RPC=$3
    local STATE_SYNC_PEER=$4
    local BIN_NAME=$5

    if [ -z "$HOME_DIR" ] || [ -z "$STATE_SYNC_RPC" ] || [ -z "$STATE_SYNC_PEER" ] || [ -z "$BIN_NAME" ]; then
        echo -e "\nRequired $CHAIN chain variables are missing.\nPlease check the chains configuration file\nSkipping snapshot for $CHAIN.\n"
        return 1
    fi

    if [ ! -d "$HOME_DIR" ]; then
        echo -e "\n$CHAIN directory $HOME_DIR does not exist...\nIs the chain installed?\nSkipping snapshot for $CHAIN.\n"
        return 1
    fi

    RPC_HOST=$(echo "$STATE_SYNC_RPC" | awk -F[/:] '{print $4}')

    if ! curl -s --head "$RPC_HOST" | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null; then
        echo -e "\n$CHAIN State sync $RPC_HOST RPC is not reachable\nSkipping snapshot for $CHAIN.\n"
        return 1
    fi

    PEER_HOST=$(echo "$STATE_SYNC_PEER" | awk -F'[@:]' '{print $2}')
    PEER_PORT=$(echo "$STATE_SYNC_PEER" | awk -F'[@:]' '{print $3}')

    if ! nc -z "$PEER_HOST" "$PEER_PORT"; then
        echo -e "\n$CHAIN State sync $STATE_SYNC_PEER P2P is not reachable\nSkipping snapshot for $CHAIN.\n"
        return 1
    fi

    if ! command -v "$BIN_NAME" &> /dev/null; then
        echo -e "\nBinary $BIN_NAME is not executable\nSkipping snapshot for $CHAIN.\n"
        return 1
    fi
}

TRAP() {
    END_TIME=$(date +%s)
    TIME_TAKEN=$((END_TIME - START_TIME))
    TOTAL_SIZE_MB=$(echo "$TOTAL_SIZE * 1024" | bc)
    TRANSFER_SPEED=$(echo "scale=2; $TOTAL_SIZE_MB / $TIME_TAKEN" | bc)
    echo $TOTAL_SNAPSHOTS > "$SNAPSHOT_COUNT_FILE"


    echo -e "\n\nNumber of Snapshots created: $GLOB_COUNT of $TOTAL_CHAINS"
    echo -e "Total time taken: $TIME_TAKEN seconds"
    echo -e "Total file size: $TOTAL_SIZE GB"
    echo -e "Snapshot speed (Reset+Sync+Compress+Copy): $TRANSFER_SPEED MB/s\n"
    echo -e "====================================================================\n"
    echo -e "Total number of Snapshots created using SNAPMAKER: $TOTAL_SNAPSHOTS"
    echo -e "====================================================================\n"

    {
        echo -e "============================================================\n"
        echo -e "\nRun Date: $(date)"
        echo -e "Number of Snapshots created: $GLOB_COUNT of $TOTAL_CHAINS"
        echo -e "Total time taken: $TIME_TAKEN seconds"
        echo -e "Total file size: $TOTAL_SIZE GB"
        echo -e "Snapshot speed (Reset+Sync+Compress+Copy): $TRANSFER_SPEED MB/s"
        echo -e "\n============================================================"
        echo -e "\nNumber of Snapshots created so far: $TOTAL_SNAPSHOTS\n"
        echo -e "============================================================\n"
    } >> "$SNAP_FULL_LOG"

    if [[ -n "$NOTIFY" ]]; then
        cat "$SNAP_LAST_LOG" | mail -s "NexuSecurus SNAPMaker Report" "$NOTIFY"
    fi

    rm -rf "$SNAP_TMP_DIR" "$JSON_TMP_DIR"

}
trap TRAP EXIT

ADD_JSON_INFO() {
    local CHAIN_NAME=$1
    local SNAP_NAME=$2
    local SNAP_SIZE=$3
    local CHECKSUM=$4
    local DATE=$5
    local EARLY_BLOCK_SYNC=$6
    local LATEST_BLOCK_SYNC=$7
    local SNAP_URL=$8
    local ADDR_NAME=$9
    local ADDR_SIZE=${10}
    local ADDR_BOOK_URL=${11}
    local GENESIS_NAME=${12}
    local GENESIS_SIZE=${13}
    local GENESIS_URL=${14}
    local PRUNE=${15}
    local INDEXER=${16}
    local BIN_VER=${17}

    cat >> "$JSON_FILE" <<EOF
    {
        "chain_name": "$CHAIN_NAME",
        "snap_name": "$SNAP_NAME",
        "snap_size": "$SNAP_SIZE",
        "checksum": "$CHECKSUM",
        "date": "$DATE",
        "early_block": "$EARLY_BLOCK_SYNC",
        "last_block": "$LATEST_BLOCK_SYNC",
        "snap_url": "$SNAP_URL",
        "addr_name": "$ADDR_NAME",
        "addr_size": "$ADDR_SIZE",
        "addr_book_url": "$ADDR_BOOK_URL",
        "genesis_name": "$GENESIS_NAME",
        "genesis_size": "$GENESIS_SIZE",
        "genesis_url": "$GENESIS_URL",
        "pruning": "$PRUNE",
        "indexer": "$INDEXER",
        "bin_ver": "$BIN_VER"
    },
EOF
}

echo "[" > "$JSON_FILE"

PROCESS_CHAIN() {
    local CHAIN=$1
    local PRUNING="100/0/10"
    local INDEX="null"

    IFS=',' read -r HOME_DIR STATE_SYNC_RPC STATE_SYNC_PEER BIN_NAME SERVICE_NAME RPC_PORT <<< "${CHAINS[$CHAIN]}"

    echo -e "\nProcessing $CHAIN Snapshot ($JOB of $TOTAL_CHAINS)\n"

    VER=$($BIN_NAME version)
    
    echo -e "\nResetting $CHAIN Blockchain data\n"
    
    sudo systemctl stop $SERVICE_NAME
    cp -v $HOME_DIR/data/priv_validator_state.json $HOME_DIR/priv_validator_state.json.backup
    $BIN_NAME tendermint unsafe-reset-all --keep-addr-book --home $HOME_DIR
    
    echo -e "\n$CHAIN data reset complete!!!\n"

    LATEST_HEIGHT=$(curl -s $STATE_SYNC_RPC/block | jq -r .result.block.header.height)
    SYNC_BLOCK_HEIGHT=$(($LATEST_HEIGHT - $SNAPSHOT_INTERVAL))
    SYNC_BLOCK_HASH=$(curl -s "$STATE_SYNC_RPC/block?height=$SYNC_BLOCK_HEIGHT" | jq -r .result.block_id.hash)
    
    sed -i \
        -e "s|^enable *=.*|enable = true|" \
        -e "s|^rpc_servers *=.*|rpc_servers = \"$STATE_SYNC_RPC,$STATE_SYNC_RPC\"|" \
        -e "s|^trust_height *=.*|trust_height = $SYNC_BLOCK_HEIGHT|" \
        -e "s|^trust_hash *=.*|trust_hash = \"$SYNC_BLOCK_HASH\"|" \
        -e "s|^persistent_peers *=.*|persistent_peers = \"$STATE_SYNC_PEER\"|" \
    $HOME_DIR/config/config.toml

    mv $HOME_DIR/priv_validator_state.json.backup $HOME_DIR/data/priv_validator_state.json

    sudo systemctl start $SERVICE_NAME
    echo -e "\nStarting $SERVICE_NAME...\n"
    sleep 5

    echo -e "\nWait for $CHAIN Blockchain to finish syncing\n"
    echo -n "Syncing activity: "

    while true; do
        SYNC_STATUS=$(curl -s http://localhost:$RPC_PORT/status | jq -r .result.sync_info.catching_up)

        if [ -z "$SYNC_STATUS" ]; then
            echo -e "Failed to get $CHAIN chain status. Something went wrong.\nThere is no RPC endpoint at http://localhost:$RPC_PORT, or the service is not running.\nSkipping snapshot for $CHAIN.\n"
            return
        fi

        if [ "$SYNC_STATUS" == "true" ]; then
            echo -n "-*-"
        else
            echo -e "  --> Sync Complete!!!\n"
            break
        fi
        sleep 3
    done

    sudo systemctl stop $SERVICE_NAME

    echo -e "\nStopping $SERVICE_NAME...\n"
    sleep 3

    echo -e "\nCompressing $CHAIN Blockchain data\n"
    
    tar --use-compress-program=lz4 -cf $SNAP_TMP_DIR/$CHAIN-snap-latest.tar.lz4 -C $HOME_DIR data
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to compress $CHAIN data folder.\nSkipping snapshot for $CHAIN.\nSkipping snapshot for $CHAIN.\n"
        return
    fi

    echo -e "\nCompression complete!!!\n"
    SNAP_FILE_SIZE_BYTES=$(du -b $SNAP_TMP_DIR/$CHAIN-snap-latest.tar.lz4 | cut -f1)
    SNAP_FILE_SIZE_GB=$(echo -e "scale=2; $SNAP_FILE_SIZE_BYTES / 1073741824" | bc)
    
    if (( $(echo "$SNAP_FILE_SIZE_GB < 1" | bc -l) )); then
        SNAP_FILE_SIZE_GB="0$SNAP_FILE_SIZE_GB"
    fi

    FILE_CHECKSUM=$(md5sum $SNAP_TMP_DIR/$CHAIN-snap-latest.tar.lz4 | cut -d ' ' -f1)
    SNAP_FILE_DATE=$(date -r $SNAP_TMP_DIR/$CHAIN-snap-latest.tar.lz4)
    SNAP_URL="https://snapshots.nexusecurus.com/blockchains/$CHAIN/snapshot/$CHAIN-snap-latest.tar.lz4"
    echo -e "Details:\nFile: $CHAIN-snap-latest.tar.lz4\nSize: $SNAP_FILE_SIZE_GB GB\n"

    TOTAL_SIZE=$(echo "$TOTAL_SIZE + $SNAP_FILE_SIZE_GB" | bc)
    
    if (( $(echo "$TOTAL_SIZE < 1" | bc -l) )); then
        TOTAL_SIZE="0$TOTAL_SIZE"
    fi
    
    CHAIN_DIR="$BLOCKCHAIN_DIR/$CHAIN"

    echo -e "\nMoving snapshot compressed file to $REMOTE_HOST:$CHAIN_DIR/snapshot\n"
    
    ssh -i $SSH_KEY -p $REMOTE_SSH_PORT $REMOTE_HOST -o StrictHostKeyChecking=no "mkdir -v -p $CHAIN_DIR/snapshot"
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to create $CHAIN_DIR/snapshot directory on $REMOTE_HOST.\nSkipping snapshot for $CHAIN.\n"
        return
    fi
    
    rsync -avz --progress --remove-source-files -e "ssh -i $SSH_KEY -p $REMOTE_SSH_PORT -o StrictHostKeyChecking=no" $SNAP_TMP_DIR/$CHAIN-snap-latest.tar.lz4 $REMOTE_HOST:$CHAIN_DIR/snapshot/
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to copy $CHAIN-snap-latest.tar.lz4 to $REMOTE_HOST:$CHAIN_DIR/snapshot.\nSkipping snapshot for $CHAIN.\n"
        return
    fi

    echo -e "\n$CHAIN Snapshot compressed file has been successfully copied. Local file deleted!!!\n"

    ADDR_NAME="addrbook.json"
    ADDR_BOOK_URL="https://snapshots.nexusecurus.com/blockchains/$CHAIN/addrbook/addrbook.json"
    ADDR_FILE_SIZE_BYTES=$(du -b $HOME_DIR/config/addrbook.json | cut -f1)
    ADDR_FILE_SIZE_MB=$(echo -e "scale=2; $ADDR_FILE_SIZE_BYTES / 1048576" | bc)

    if (( $(echo "$ADDR_FILE_SIZE_MB < 1" | bc -l) )); then
        ADDR_FILE_SIZE_MB="0$ADDR_FILE_SIZE_MB"
    fi
    
    echo -e "\nCopying addrbook file to $REMOTE_HOST:$CHAIN_DIR/addrbook\n"
    
    ssh -i $SSH_KEY -p $REMOTE_SSH_PORT $REMOTE_HOST -o StrictHostKeyChecking=no "mkdir -v -p $CHAIN_DIR/addrbook"
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to create $CHAIN_DIR/addrbook directory on $REMOTE_HOST.\nSkipping snapshot for $CHAIN.\n"
        return
    fi

    rsync -avz --progress -e "ssh -i $SSH_KEY -p $REMOTE_SSH_PORT -o StrictHostKeyChecking=no" $HOME_DIR/config/addrbook.json $REMOTE_HOST:$CHAIN_DIR/addrbook/
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to copy $HOME_DIR/config/addrbook.json to $REMOTE_HOST:$CHAIN_DIR/addrbook.\nSkipping snapshot for $CHAIN.\n"
        return
    fi

    echo -e "\n$CHAIN addrbook file has been successfully copied!!!\n"

    GENESIS_NAME="genesis.json"
    GENESIS_URL="https://snapshots.nexusecurus.com/blockchains/$CHAIN/genesis/genesis.json"
    GEN_FILE_SIZE_BYTES=$(du -b $HOME_DIR/config/genesis.json | cut -f1)
    GEN_FILE_SIZE_MB=$(echo -e "scale=2; $GEN_FILE_SIZE_BYTES / 1048576" | bc)

    if (( $(echo "$GEN_FILE_SIZE_MB < 1" | bc -l) )); then
        GEN_FILE_SIZE_MB="0$GEN_FILE_SIZE_MB"
    fi

    echo -e "\nCopying genesis file to $REMOTE_HOST:$CHAIN_DIR/genesis\n"
    
    ssh -i $SSH_KEY -p $REMOTE_SSH_PORT $REMOTE_HOST -o StrictHostKeyChecking=no "mkdir -v -p $CHAIN_DIR/genesis"
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to create $CHAIN_DIR/genesis directory on $REMOTE_HOST.\nSkipping snapshot for $CHAIN.\n"
        return
    fi
    
    rsync -avz --progress -e "ssh -i $SSH_KEY -p $REMOTE_SSH_PORT -o StrictHostKeyChecking=no" $HOME_DIR/config/genesis.json $REMOTE_HOST:$CHAIN_DIR/genesis/
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to copy $HOME_DIR/config/genesis.json to $REMOTE_HOST:$CHAIN_DIR/genesis.\nSkipping snapshot for $CHAIN.\n"
        return
    fi
    
    echo -e "\n$CHAIN genesis file has been successfully copied!!!\n"
    echo -e "All $CHAIN files were successfully copied to $REMOTE_HOST:$CHAIN_DIR\nSnapshot complete.\n"
    echo -e "\nJob: $JOB of $TOTAL_CHAINS complete!!!\n"
    echo -e "============================================================\n"

    GLOB_COUNT=$((GLOB_COUNT+1))
    JOB=$((JOB+1))
    TOTAL_SNAPSHOTS=$((TOTAL_SNAPSHOTS+1))

    ADD_JSON_INFO "$CHAIN" "$CHAIN-snap-latest.tar.lz4" "$SNAP_FILE_SIZE_GB" "$FILE_CHECKSUM" "$SNAP_FILE_DATE" "$SYNC_BLOCK_HEIGHT" "$LATEST_HEIGHT" "$SNAP_URL" "$ADDR_NAME" "$ADDR_FILE_SIZE_MB" "$ADDR_BOOK_URL" "$GENESIS_NAME" "$GEN_FILE_SIZE_MB" "$GENESIS_URL" "$PRUNING" "$INDEX" "$VER"

}

echo -e "\nInitializing SNAPMAKER for Cosmos Ecosystem\n\n"
echo -e "Chains currently queued for processing: $TOTAL_CHAINS\n\n"
echo -e "============================================================\n"

for CHAIN in "${!CHAINS[@]}"; do
    IFS=',' read -r HOME_DIR STATE_SYNC_RPC STATE_SYNC_PEER BIN_NAME SERVICE_NAME RPC_PORT <<< "${CHAINS[$CHAIN]}"
    if CHECKS "$CHAIN" "$HOME_DIR" "$STATE_SYNC_RPC" "$STATE_SYNC_PEER" "$BIN_NAME" "$SERVICE_NAME" "$RPC_PORT"; then
        PROCESS_CHAIN "$CHAIN"
    else
        echo -e "\nSkipping $CHAIN due to failed checks.\n"
        JOB=$((JOB + 1))
    fi
done

sed -i '$ s/,$//' "$JSON_FILE"
echo "]" >> "$JSON_FILE"

echo -e "\nUpdating $JSON_FILE in $REMOTE_HOST:$DEST_DIR/snap_metrics\n"

ssh -i $SSH_KEY -p $REMOTE_SSH_PORT $REMOTE_HOST -o StrictHostKeyChecking=no "mkdir -v -p $DEST_DIR/snap_metrics"
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to create $DEST_DIR/snap_metrics directory on $REMOTE_HOST."
        exit 1
    fi

rsync -avz --remove-source-files --progress -e "ssh -i $SSH_KEY -p $REMOTE_SSH_PORT -o StrictHostKeyChecking=no" $JSON_FILE $REMOTE_HOST:$DEST_DIR/snap_metrics/
    
    if [ $? -ne 0 ]; then
        echo -e "\nFailed to copy $JSON_FILE to $REMOTE_HOST:$DEST_DIR/snap_metrics.\n"
        exit 1 
    fi

echo -e "\n$JSON_FILE has been successfully copied!!!\n"


echo -e "\nSNAPMAKER Queued Jobs have been successfully completed!!!\n"
