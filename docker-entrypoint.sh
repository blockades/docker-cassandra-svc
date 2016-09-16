#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
	set -- cassandra -f "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'cassandra' -a "$(id -u)" = '0' ]; then
	chown -R cassandra /var/lib/cassandra /var/log/cassandra "$CASSANDRA_CONFIG"
	exec gosu cassandra "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'cassandra' ]; then
	: ${CASSANDRA_RPC_ADDRESS='0.0.0.0'}

	: ${CASSANDRA_LISTEN_ADDRESS='auto'}
	if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
		CASSANDRA_LISTEN_ADDRESS="$(hostname --ip-address | awk '{print $1}')"
	fi

	: ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

	if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
		CASSANDRA_BROADCAST_ADDRESS="$(hostname --ip-address | awk '{print $1}')"
	fi
	: ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

	if [ -n "${CASSANDRA_NAME:+1}" ]; then
		: ${CASSANDRA_SEEDS:="cassandra"}
	fi
	: ${CASSANDRA_SEEDS:="$CASSANDRA_BROADCAST_ADDRESS"}

	sed -ri 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/' "$CASSANDRA_CONFIG/cassandra.yaml"

	: ${CASSANDRA_READ_REQUEST_TIMEOUT_IN_MS:=10000}
	: ${CASSANDRA_WRITE_REQUEST_TIMEOUT_IN_MS:=10000}
	: ${CASSANDRA_CONCURRENT_READS:=32}
	: ${CASSANDRA_CONCURRENT_WRITES:=32}
	: ${CASSANDRA_CONCURRENT_COUNTER_WRITES:=32}
	: ${CASSANDRA_CONCURRENT_COMPACTORS:=2}
	: ${CASSANDRA_MEMTABLE_FLUSH_WRITERS:=2}
	: ${CASSANDRA_MEMTABLE_HEAP_SPACE_IN_MB:=2048}
	: ${CASSANDRA_MEMTABLE_OFFHEAP_SPACE_IN_MB:=2048}

	for yaml in \
		broadcast_address \
		broadcast_rpc_address \
		cluster_name \
		endpoint_snitch \
		listen_address \
		num_tokens \
		rpc_address \
		start_rpc \
		read_request_timeout_in_ms \
		write_request_timeout_in_ms \
		concurrent_reads \
		concurrent_writes \
		concurrent_counter_writes \
		concurrent_compactors \
		memtable_flush_writers \
		memtable_heap_space_in_mb \
		memtable_offheap_space_in_mb \
	; do
		var="CASSANDRA_${yaml^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CONFIG/cassandra.yaml"
		fi
	done

	for rackdc in dc rack; do
		var="CASSANDRA_${rackdc^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^('"$rackdc"'=).*/\1 '"$val"'/' "$CASSANDRA_CONFIG/cassandra-rackdc.properties"
		fi
	done
fi

exec "$@"
