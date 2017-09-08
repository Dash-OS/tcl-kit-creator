#! /usr/bin/env bash

PATCH="${PATCH:-patch}"
if [ ! -x "$(which "${PATCH}" 2>/dev/null)" ]; then
	echo "No \"${PATCH}\" command (for patch)."
	echo "No \"${PATCH}\" command (for patch)." >&4

	exit 1
fi

exit 0
