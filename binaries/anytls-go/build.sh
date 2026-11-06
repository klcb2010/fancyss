#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
SOURCE_COMMIT="9666872946857b50a74fdb692896d77b53773cb2"
FALLBACK_BIN="${ROOT}/binaries/anytls-go/anytls-client"

use_fallback() {
    echo "WARNING: AnyTLS upstream source unavailable; using repository fallback binary."
    if [ ! -s "${FALLBACK_BIN}" ]; then
        echo "ERROR: fallback AnyTLS binary is missing or empty: ${FALLBACK_BIN}" >&2
        exit 1
    fi
    chmod 755 "${FALLBACK_BIN}"
    if ! file "${FALLBACK_BIN}" | grep -q 'ELF 64-bit.*ARM aarch64'; then
        echo "ERROR: fallback AnyTLS binary is not a valid Linux ARM64 ELF executable." >&2
        file "${FALLBACK_BIN}" >&2 || true
        exit 1
    fi
    sha256sum "${FALLBACK_BIN}"
    echo "Using the checked-in AnyTLS ARM64 client; build can continue."
}

git -C "${WORK}" init -q
git -C "${WORK}" remote add origin https://github.com/anytls/anytls-go.git

# Fetch upstream first. If the repository, commit, or network is unavailable,
# keep the checked-in ARM64 client instead of failing the entire package build.
if ! git -C "${WORK}" fetch --depth=1 origin "${SOURCE_COMMIT}"; then
    use_fallback
    exit 0
fi

if ! git -C "${WORK}" checkout -q --detach FETCH_HEAD; then
    use_fallback
    exit 0
fi

# Apply the CLI compatibility changes and the Stream.dieErr race fix from
# anytls-go issue #54. Fail closed if the expected upstream source has changed.
python3 - "${WORK}" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

def replace_once(path, old, new, label):
    src = path.read_text()
    count = src.count(old)
    if count != 1:
        raise SystemExit(f"ERROR: {label}: expected one match, found {count}")
    path.write_text(src.replace(old, new, 1))

# Fix issue #54: publish the error interface atomically as one immutable value.
stream = root / "proxy/session/stream.go"
replace_once(
    stream,
    '\t"sync"\n',
    '\t"sync"\n\t"sync/atomic"\n',
    "stream.go atomic import",
)
replace_once(
    stream,
    '\tdieOnce sync.Once\n\tdieHook func()\n\tdieErr  error\n',
    '\tdieOnce sync.Once\n\tdieHook func()\n\tdieErr  atomic.Pointer[streamCloseError]\n',
    "stream.go dieErr field",
)
replace_once(
    stream,
    '// newStream initiates a Stream struct\n',
    '// Publish both words of the error interface together. Stream operations may\n'
    '// race with session shutdown; sync.Once alone does not protect ordinary reads.\n'
    'type streamCloseError struct {\n'
    '\terr error\n'
    '}\n\n'
    'func (s *Stream) closeError() error {\n'
    '\tif state := s.dieErr.Load(); state != nil {\n'
    '\t\treturn state.err\n'
    '\t}\n'
    '\treturn nil\n'
    '}\n\n'
    '// newStream initiates a Stream struct\n',
    "stream.go atomic error helper",
)
replace_once(
    stream,
    '\tif n == 0 && s.dieErr != nil {\n\t\terr = s.dieErr\n\t}\n',
    '\tif closeErr := s.closeError(); n == 0 && closeErr != nil {\n\t\terr = closeErr\n\t}\n',
    "stream.go Read",
)
replace_once(
    stream,
    '\tif s.dieErr != nil {\n\t\treturn 0, s.dieErr\n\t}\n',
    '\tif closeErr := s.closeError(); closeErr != nil {\n\t\treturn 0, closeErr\n\t}\n',
    "stream.go Write",
)
replace_once(
    stream,
    '\t\ts.dieErr = net.ErrClosed\n',
    '\t\ts.dieErr.Store(&streamCloseError{err: net.ErrClosed})\n',
    "stream.go closeLocally",
)
replace_once(
    stream,
    '\t\ts.dieErr = err\n',
    '\t\ts.dieErr.Store(&streamCloseError{err: err})\n',
    "stream.go closeWithError store",
)
replace_once(
    stream,
    '\t\treturn s.dieErr\n',
    '\t\treturn s.closeError()\n',
    "stream.go closeWithError return",
)

# Existing fancyss command-line compatibility patch.
path = root / "cmd/client/main.go"
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
        raise SystemExit("ERROR: AnyTLS CLI source patch did not apply: " + token)
path.write_text(src)
PY

cd "${WORK}"
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -buildvcs=false -ldflags="-s -w" -o "${FALLBACK_BIN}" ./cmd/client
chmod 755 "${FALLBACK_BIN}"
if ! file "${FALLBACK_BIN}" | grep -q 'ELF 64-bit.*ARM aarch64'; then
    echo "ERROR: newly built AnyTLS client is not a Linux ARM64 ELF executable." >&2
    file "${FALLBACK_BIN}" >&2 || true
    exit 1
fi
echo "Built patched AnyTLS Go client (including issue #54 fix):"
file "${FALLBACK_BIN}"
sha256sum "${FALLBACK_BIN}"
