#!/bin/sh

#参考文档
#https://developer.android.com/ndk/guides/other_build_systems?hl=zh-cn#autoconf

# 特别注意：
# WSL2上 ndk23及以上会报错 checking whether the C compiler works... no
# 在M1的MacBookPro上 x86构建会报错 用ndk22版本正常
# 在ubuntu上面 ndk25 构建正常

#NDK_ROOT=~/Library/android/sdk/ndk/18.1.5063045
#NDK_ROOT=$ANDROID_HOME/ndk/25.2.9519653
NDK_ROOT=$ANDROID_HOME/ndk/22.1.7171670

echo "setup-ndk-env ${NDK_ROOT} abi: "$1

# Android NDK的版本号由三部分组成：主版本号、次版本号和修订版本号。
# 例如25.2.9519653，主版本号为21，次版本号为3，修订版本号为6528147。
# Android NDK的版本号通常与对应的Android SDK版本号相对应，以确保NDK的兼容性。

NDK_VERSION=`sed '/^Pkg.Revision = /!d;s/.*=//' $NDK_ROOT/source.properties`
ndkVerArray=(${NDK_VERSION//./ })
echo "ndkVersion:$NDK_VERSION"

export NDK_MAJOR_VERSION=${ndkVerArray[0]}
export NDK_MINOR_VERSION=${ndkVerArray[1]}
export NDK_REVISION_VERSION=${ndkVerArray[2]}

#校验当前操作系统-目前只支持linux和macOS
export OS_NAME="$(uname -s | tr 'A-Z' 'a-z')"

if [[ $OS_NAME == "darwin" ]];
then
    NDK_HOST_TAG="darwin-x86_64"
elif [[ $OS_NAME == "linux" ]];
then
    NDK_HOST_TAG="linux-x86_64"
else
    echo "Unsupported OS."
    exit
fi

# 目标文件是否存在
function file_exit {
    TARGET_NAME=$1
    TARGET_FILE=$2
    if [ -f "${TARGET_FILE}" ];then
        echo ${TARGET_NAME}${TARGET_FILE}
    else
        echo "File not exist. "${TARGET_NAME}${TARGET_FILE}
    fi
}

#适用于NDK版本在19及以上
function export_env_new_target {
    TARGET_ABI=$1
    case $TARGET_ABI in
        arm64-v8a)
            TOOLCHAIN_BASE=aarch64-linux-android
            TOOL_NAME_BASE=aarch64-linux-android
        ;;
        armeabi-v7a)
            TOOLCHAIN_BASE=armv7a-linux-androideabi
            TOOL_NAME_BASE=armv7a-linux-androideabi
        ;;
        x86_64)
            TOOLCHAIN_BASE=x86_64-linux-android
            TOOL_NAME_BASE=x86_64-linux-android
        ;;
        x86)
            TOOLCHAIN_BASE=i686-linux-android
            TOOL_NAME_BASE=i686-linux-android
        ;;
        *)
            echo "Unsupported ABI."$TARGET_ABI
        ;;
    esac
    #导出环境变量
    export TOOLCHAIN_BASE=$TOOLCHAIN_BASE
    export TOOL_NAME_BASE=$TOOL_NAME_BASE
}

function export_env_new {
    TARGET_ABI=$1
    # 设置最低的SDK版本
    export API=21

    export_env_new_target $TARGET_ABI
    
    # 根据当前机器类型选择构建工具链 darwin-x86_64/linux-x86_64
    export TOOLCHAIN=$NDK_ROOT/toolchains/llvm/prebuilt/${NDK_HOST_TAG}
    
    export AR=${TOOLCHAIN}/bin/llvm-ar
    export CC=${TOOLCHAIN}/bin/${TOOLCHAIN_BASE}${API}-clang
    export AS=$CC
    export CXX=${TOOLCHAIN}/bin/${TOOLCHAIN_BASE}${API}-clang++
    export LD=${TOOLCHAIN}/bin/ld
    export RANLIB=${TOOLCHAIN}/bin/llvm-ranlib
    export STRIP=${TOOLCHAIN}/bin/llvm-strip
    
    file_exit "AR=" $AR
    file_exit "CC=" $CC
    file_exit "AS=" $AS
    file_exit "CXX=" $CXX
    file_exit "LD=" $LD
    file_exit "RANLIB=" $RANLIB
    file_exit "STRIP=" $STRIP
}

#适用于NDK版本在19以下
function export_env_old_target {
    TARGET_ABI=$1
    case $TARGET_ABI in
        arm64-v8a)
            TOOLCHAIN_BASE=aarch64-linux-android
            TOOL_NAME_BASE=aarch64-linux-android
        ;;
        armeabi-v7a)
            TOOLCHAIN_BASE=arm-linux-androideabi
            TOOL_NAME_BASE=arm-linux-androideabi
        ;;
        x86_64)
            TOOLCHAIN_BASE=x86_64
            TOOL_NAME_BASE=x86_64-linux-android
        ;;
        x86)
            TOOLCHAIN_BASE=x86
            TOOL_NAME_BASE=i686-linux-android
        ;;
        *)
            echo "Unsupported ABI."$TARGET_ABI
            exit
        ;;
    esac
    #导出环境变量
    export TOOLCHAIN_BASE=$TOOLCHAIN_BASE
    export TOOL_NAME_BASE=$TOOL_NAME_BASE
}

function export_env_old {
    TARGET_ABI=$1
    #导出TARGET环境变量
    export_env_old_target ${TARGET_ABI}
    
    TOOLCHAIN=${NDK_ROOT}/toolchains/${TOOLCHAIN_BASE}-4.9/prebuilt/${NDK_HOST_TAG}
    
    export AR=${TOOLCHAIN}/bin/${TOOL_NAME_BASE}-ar
    export CC=${TOOLCHAIN}/bin/${TOOL_NAME_BASE}-gcc
    export AS=$CC
    export CXX=${TOOLCHAIN}/bin/${TOOL_NAME_BASE}-g++
    export LD=${TOOLCHAIN}/bin/${TOOL_NAME_BASE}-ld
    export RANLIB=${TOOLCHAIN}/bin/${TOOL_NAME_BASE}-ranlib
    export STRIP=${TOOLCHAIN}/bin/${TOOL_NAME_BASE}-strip

    file_exit "AR=" $AR
    file_exit "CC=" $CC
    file_exit "AS=" $AS
    file_exit "CXX=" $CXX
    file_exit "LD=" $LD
    file_exit "RANLIB=" $RANLIB
    file_exit "STRIP=" $STRIP
}

#用来判断NDK版本是否为19及以上
NDK_NEW_LLVM_CONFIG=${NDK_ROOT}/toolchains/llvm/prebuilt/${NDK_HOST_TAG}/bin/llvm-config

if [ -f "${NDK_NEW_LLVM_CONFIG}" ];then
    #NDK版本为19及以上
    echo "ndk version >= 19 abi: "$1
    export_env_new $1
else
    #NDK版本为19以下
    echo "ndk version < 19 abi: "$1
    export_env_old $1
fi