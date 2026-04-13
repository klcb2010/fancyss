规则部分 
# 覆盖 ss_update.sh 和自定义名单
    cp -f "${CURR_PATH}/ss_update.sh" "${CURR_PATH}/fancyss/scripts/ss_update.sh"
    cp -f "${CURR_PATH}/black_list.txt" "${target}/black_list.txt"
    cp -f "${CURR_PATH}/white_list.txt" "${target}/white_list.txt"






二进制部分

sync_binary(){
    local BINS_COPY="xray naive ipt2socks"
    for BIN in $BINS_COPY; do
        local VERSION_FLAG="latest.txt"
        [ "$BIN" == "xray" ] && VERSION_FLAG="latest_2.txt"
        local version=$(cat ${CURR_PATH}/binaries/${BIN}/${VERSION_FLAG})
        echo ">>> copy $BIN, version: $version"

        check_file_exist ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_arm64
        check_file_exist ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_armv7
        check_file_exist ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_armv5

        cp -rf ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_arm64 ${CURR_PATH}/fancyss/bin-mtk/${BIN}
        cp -rf ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_arm64 ${CURR_PATH}/fancyss/bin-hnd_v8/${BIN}
        cp -rf ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_armv7 ${CURR_PATH}/fancyss/bin-ipq32/${BIN}
        cp -rf ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_armv7 ${CURR_PATH}/fancyss/bin-hnd/${BIN}
        cp -rf ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_armv7 ${CURR_PATH}/fancyss/bin-qca/${BIN}
        cp -rf ${CURR_PATH}/binaries/${BIN}/${version}/${BIN}_armv5 ${CURR_PATH}/fancyss/bin-arm/${BIN}
    done




    打包部分
    build_pkg() {
    local platform=$1
    local pkgtype=$2
    local release_type=$3
    if [ ${release_type} == "release" ];then
        echo "打包：fancyss_${platform}_${pkgtype}.tar.gz"
        tar -zcf ${CURR_PATH}/packages/fancyss_${platform}_${pkgtype}.tar.gz shadowsocks >/dev/null
        md5value=$(md5sum ${CURR_PATH}/packages/fancyss_${platform}_${pkgtype}.tar.gz | tr " " "\n" | sed -n 1p)
        cat >>${CURR_PATH}/packages/version_tmp.json.js <<-EOF
,"md5_${platform}_${pkgtype}":"${md5value}"
EOF
    elif [ ${release_type} == "debug" ];then
        echo "打包：fancyss_${platform}_${pkgtype}_${release_type}.tar.gz"
        tar -zcf ${CURR_PATH}/packages/fancyss_${platform}_${pkgtype}_${release_type}.tar.gz shadowsocks >/dev/null
    fi
}

papare(){
    mkdir -p "${CURR_PATH}/packages"
    rm -f ${CURR_PATH}/packages/*
    cp_rules
    prepare_geodata_assets
    cp_rules_ng2
    sync_binary
    cat >${CURR_PATH}/packages/version_tmp.json.js <<-EOF
{
"name":"fancyss"
,"version":"${VERSION}"
EOF
}

finish(){
    echo "}" >>${CURR_PATH}/packages/version_tmp.json.js
    cat ${CURR_PATH}/packages/version_tmp.json.js | jq '.' >${CURR_PATH}/packages/version.json.js
    rm -rf ${CURR_PATH}/packages/version_tmp.json.js
    echo "完成！生成的离线安装包在发布页"
}

pack(){
    gen_folder $1 $2 $3
    build_pkg $1 $2 $3
    rm -rf ${CURR_PATH}/shadowsocks/
}

make(){
    papare
    # --- 只打包 full 版本
    pack hnd full release
    pack hnd_v8 full release
    pack qca full release
    pack arm full release
    pack mtk full release
    pack ipq32 full release
    pack ipq64 full release
    finish
}

make
