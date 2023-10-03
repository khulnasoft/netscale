VERSION=$(git describe --tags --always --match "[0-9][0-9][0-9][0-9].*.*")
echo $VERSION

export TARGET_OS=windows
# This controls the directory the built artifacts go into
export ARTIFACT_DIR=built_artifacts/
mkdir -p $ARTIFACT_DIR
windowsArchs=("amd64" "386")
for arch in ${windowsArchs[@]}; do
    export TARGET_ARCH=$arch
    # Copy exe into final directory
    cp ./artifacts/netscale-windows-$arch.exe $ARTIFACT_DIR/netscale-windows-$arch.exe
    cp ./artifacts/netscale-windows-$arch.exe ./netscale.exe
    make netscale-msi
    # Copy msi into final directory
    mv netscale-$VERSION-$arch.msi $ARTIFACT_DIR/netscale-windows-$arch.msi
done