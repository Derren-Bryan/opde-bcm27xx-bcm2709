#!/bin/bash

echoerr() { echo "$@" 1>&2; }
exiterr() { echoerr "$@" ; exit 1; }

# variable check if exist
function check_var_not_set() {
	if [[ -v $1 ]]; then
		# echo "[info]: $1 = ${!1}"
		return 0
	else
		echoerr "[ERROR]: Variable '$1' is not defined"
		exit 1
	fi
}

check_var_not_set SCRIPT_ABS_PATH
check_var_not_set SOURCE_NAME
check_var_not_set FEEDS_CONF
check_var_not_set BASE_PACK_CONF
check_var_not_set USER_PACK_CONF

# internal variable
SOURCE_BASE_PATH="$SCRIPT_ABS_PATH/$SOURCE_NAME"
GLOBAL_ARGS="$@"
PACK_CONF=""
BUILD_SDK_PACK_CONF=""

# args check
argsContains () {
	for item in $GLOBAL_ARGS
	do
		if [ "$item" == "$1" ] ; then
			return 0
		fi
	done
	return 1
}

count=0
(argsContains "--sdk" ) && ((count++))
(argsContains "--build-sdk") && ((count++))
(argsContains "--image") && ((count++))
if [[ count -gt 1 ]]; then
	exiterr "--build-sdk --sdk --image only one can be chosen."
fi

# main program
if ( argsContains "--help" );then
	echo -e "Args:
	--sdk			add base feeds (useful for SDK)[default is disable]
					change to sdk directory (useful for SDK)[default is disable]
					sdk configure head (useful for SDK)[default is disable]
	--feeds			update and install feeds[default is disable]
	--build-sdk		disable extra default package (useful for build SDK)[default is disable]
					do not add addon packages (useful for build SDK)[default is disable]
	--image			build image using pre-build packages
	"
	exit 0
fi


if ( argsContains "--sdk" );then
    SOURCE_BASE_PATH="${SOURCE_BASE_PATH}_sdk"
fi
if ( argsContains "--image" );then
    SOURCE_BASE_PATH="${SOURCE_BASE_PATH}_ib"
fi
cd "$SOURCE_BASE_PATH" || exiterr "path '$SOURCE_BASE_PATH' not exist"

if ( argsContains "--image" );then
	REPO_BASE_PATH="$SCRIPT_ABS_PATH/${SOURCE_NAME}_sdk/bin"
	[ -d "$REPO_BASE_PATH" ] || exiterr "repo path '$REPO_BASE_PATH' not exist"
	REPOS_PATH=$(find "$REPO_BASE_PATH/packages" -name "Packages")
	FEEDS_CONF="src imagebuilder file:packages
"
	for item in ${REPOS_PATH[*]}
	do
		item=${item%/*}
		name=${item##*/}
		# echo $item
		# echo $name
		FEEDS_CONF+="src $name file://$item
"
	done
	echo "$FEEDS_CONF">repositories.conf
	echo "$FEEDS_CONF"
	exit 0
elif ( argsContains "--build-sdk" );then
	echo "${FEEDS_CONF}">feeds.conf
elif ( argsContains "--sdk" );then
	# add base feeds (only for SDK)
	FEEDS_CONF+="
src-link base $SOURCE_BASE_PATH
"
	echo "${FEEDS_CONF}">feeds.conf
fi

if ( argsContains "--feeds" );then
    ./scripts/feeds update -a && ./scripts/feeds install -a
fi

if ( argsContains "--build-sdk" );then
    BUILD_SDK_PACK_CONF="
CONFIG_ALL_KMODS=y
$(GEN_SDK_IB y)
$(DEFAULT_EXTRA_PACKAGE n)
"
else
	BUILD_SDK_PACK_CONF="
$USER_PACK_CONF
"
fi


if ( argsContains "--sdk" );then
    SDK_PACK_CONF="
CONFIG_ALL_NONSHARED=n
CONFIG_ALL_KMODS=n
CONFIG_ALL=n
CONFIG_CCACHE=y
$USER_PACK_CONF
"
fi


PACK_CONF+="$BASE_PACK_CONF $BUILD_SDK_PACK_CONF $SDK_PACK_CONF"

echo "${PACK_CONF}"
echo "${PACK_CONF}">.config
make defconfig