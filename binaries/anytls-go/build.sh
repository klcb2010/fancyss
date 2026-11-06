#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
SOURCE_COMMIT="9666872946857b50a74fdb692896d77b53773cb2"

git -C "${WORK}" init -q
git -C "${WORK}" remote add origin https://github.com/anytls/anytls-go.git
git -C "${WORK}" fetch --depth=1 origin "${SOURCE_COMMIT}"
git -C "${WORK}" checkout -q --detach FETCH_HEAD

python3 - "${WORK}/cmd/client/main.go" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
src = path.read_text()

src = src.replace(
    'serverAddr := flag.String("s", "", "Server address or anytls:// link")',
    'serverAddr := flag.String("s", "", "Server address or anytls:// link")\n'
    '\tflag.StringVar(serverAddr, "server", "", "Server address or anytls:// link")'
)
src = src.replace(
    'password := flag.String("p", "", "Password")',
    'password := flag.String("p", "", "Password")\n'
    '\tpasswordFile := flag.String("password-file", "", "Read password from file")\n'
    '\tverify := flag.Bool("verify", false, "Verify server certificate")\n'
    '\tinsecure := flag.Bool("insecure", false, "Skip server certificate verification")\n'
    '\tshowVersion := flag.Bool("version", false, "Show version")'
)
src = src.replace(
    '\tflag.Parse()\n',
    '\tflag.Parse()\n'
    '\tif *showVersion {\n'
    '\t\tlogrus.Println(util.ProgramVersionName)\n'
    '\t\treturn\n'
    '\t}\n'
    '\tif *verify && *insecure {\n'
    '\t\tlogrus.Fatalln("--insecure and --verify cannot be used together")\n'
    '\t}\n'
    '\tif *passwordFile != "" {\n'
    '\t\tdata, err := os.ReadFile(*passwordFile)\n'
    '\t\tif err != nil { logrus.Fatalln("read password file:", err) }\n'
    '\t\t*password = strings.TrimRight(string(data), "\\r\\n")\n'
    '\t}\n'
)
src = src.replace(
    '\ttlsConfig := &tls.Config{\n'
    '\t\tServerName:         *sni,\n'
    '\t\tInsecureSkipVerify: true,\n'
    '\t}\n'
    '\tif tlsConfig.ServerName == "" {\n'
    '\t\t// disable the SNI\n'
    '\t\ttlsConfig.ServerName = "127.0.0.1"\n'
    '\t}\n',
    '\ttlsConfig := &tls.Config{\n'
    '\t\tServerName:         *sni,\n'
    '\t\tInsecureSkipVerify: *insecure,\n'
    '\t}\n'
    '\tif tlsConfig.ServerName == "" {\n'
    '\t\thost, _, err := net.SplitHostPort(*serverAddr)\n'
    '\t\tif err == nil { tlsConfig.ServerName = strings.Trim(host, "[]") }\n'
    '\t}\n'
)
required = [
    'flag.StringVar(serverAddr, "server", "", "Server address or anytls:// link")',
    'passwordFile := flag.String("password-file", "", "Read password from file")',
    'verify := flag.Bool("verify", false, "Verify server certificate")',
    'insecure := flag.Bool("insecure", false, "Skip server certificate verification")',
    'os.ReadFile(*passwordFile)',
    'InsecureSkipVerify: *insecure',
]
for token in required:
    if token not in src:
        raise SystemExit("ERROR: AnyTLS source patch did not apply: " + token)
path.write_text(src)
PY

cd "${WORK}"
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -buildvcs=false -ldflags="-s -w" -o "${ROOT}/binaries/anytls-go/anytls-client" ./cmd/client
chmod 755 "${ROOT}/binaries/anytls-go/anytls-client"
echo "Built patched AnyTLS Go client:"
file "${ROOT}/binaries/anytls-go/anytls-client"
sha256sum "${ROOT}/binaries/anytls-go/anytls-client"
