#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
SOURCE_COMMIT="9666872946857b50a74fdb692896d77b53773cb2"
SOURCE_ARCHIVE="${ROOT}/binaries/anytls-go/source.tar.gz"
FETCH_DIR="${WORK}/fetch"
SOURCE_DIR="${WORK}/source"
mkdir -p "${FETCH_DIR}" "${SOURCE_DIR}"

# 优先获取固定版本的上游源码；失败时使用仓库内缓存的完整源码快照。
git -C "${FETCH_DIR}" init -q
git -C "${FETCH_DIR}" remote add origin https://github.com/anytls/anytls-go.git

if git -C "${FETCH_DIR}" fetch --depth=1 origin "${SOURCE_COMMIT}"; then
    git -C "${FETCH_DIR}" archive --format=tar FETCH_HEAD | tar -xf - -C "${SOURCE_DIR}"
    tar -czf "${SOURCE_ARCHIVE}.tmp" -C "${SOURCE_DIR}" .
    mv "${SOURCE_ARCHIVE}.tmp" "${SOURCE_ARCHIVE}"
    echo "AnyTLS source: upstream commit ${SOURCE_COMMIT}"
else
    if [ ! -s "${SOURCE_ARCHIVE}" ]; then
        echo "ERROR: upstream AnyTLS source unavailable and repository fallback is missing."
        exit 1
    fi
    tar -xzf "${SOURCE_ARCHIVE}" -C "${SOURCE_DIR}"
    echo "WARNING: upstream unavailable; using repository source snapshot."
fi

# 修复 issue #54：Stream.dieErr 原先存在并发读写 data race。
python3 - "${SOURCE_DIR}/proxy/session/stream.go" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
src = path.read_text()

def replace_once(old, new, label):
    global src
    count = src.count(old)
    if count != 1:
        raise SystemExit(f"ERROR: issue #54 patch mismatch ({label}, found {count})")
    src = src.replace(old, new, 1)

replace_once(
    '\t"sync"\n',
    '\t"sync"\n\t"sync/atomic"\n',
    "atomic import",
)
replace_once(
    '\tdieErr  error\n',
    '\tdieErr  atomic.Pointer[streamCloseError]\n',
    "dieErr field",
)
replace_once(
    '}\n\n// newStream initiates a Stream struct',
    '''}

// Publish the close error atomically so concurrent Read/Write and Close
// operations never observe a partially-written error interface.
type streamCloseError struct {
	err error
}

func (s *Stream) closeError() error {
	if state := s.dieErr.Load(); state != nil {
		return state.err
	}
	return nil
}

// newStream initiates a Stream struct''',
    "close error helper",
)
replace_once(
    '\tif n == 0 && s.dieErr != nil {\n\t\terr = s.dieErr\n\t}',
    '\tif closeErr := s.closeError(); n == 0 && closeErr != nil {\n\t\terr = closeErr\n\t}',
    "Read access",
)
replace_once(
    '\tif s.dieErr != nil {\n\t\treturn 0, s.dieErr\n\t}',
    '\tif closeErr := s.closeError(); closeErr != nil {\n\t\treturn 0, closeErr\n\t}',
    "Write access",
)
replace_once(
    '\t\ts.dieErr = net.ErrClosed',
    '\t\ts.dieErr.Store(&streamCloseError{err: net.ErrClosed})',
    "local close store",
)
replace_once(
    '\t\ts.dieErr = err',
    '\t\ts.dieErr.Store(&streamCloseError{err: err})',
    "error close store",
)
replace_once(
    '\t\treturn s.dieErr',
    '\t\treturn s.closeError()',
    "close return",
)

path.write_text(src)
PY

# 保留 fancyss 现有命令行参数兼容补丁。
python3 - "${SOURCE_DIR}/cmd/client/main.go" <<'PY'
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
        raise SystemExit("ERROR: AnyTLS client patch did not apply: " + token)
path.write_text(src)
PY

cd "${SOURCE_DIR}"
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -buildvcs=false -ldflags="-s -w" -o "${ROOT}/binaries/anytls-go/anytls-client" ./cmd/client
chmod 755 "${ROOT}/binaries/anytls-go/anytls-client"
echo "Built patched AnyTLS Go client:"
file "${ROOT}/binaries/anytls-go/anytls-client"
sha256sum "${ROOT}/binaries/anytls-go/anytls-client"
echo "Source fallback archive:"
ls -lh "${SOURCE_ARCHIVE}"
