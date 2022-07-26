#!/usr/bin/env bash

log_info() {
  echo -e "\033[32m[info]\033[0m ${1}"
}

log_debug() {
  echo -e "\033[34m[debug]\033[0m ${1}"
}

log_warn() {
  echo -e "\033[33m[warn]\033[0m ${1}" >&2
}

log_error() {
  echo -e "\033[31m[error]\033[0m ${1}" >&2
}

# Assert that the account is set.
if [[ -z "${KEYGEN_ACCOUNT}" ]]
then
  log_error 'env var KEYGEN_ACCOUNT is not set!'

  exit 1
fi

# Assert a license key is set or provided.
if [[ -z "${KEYGEN_LICENSE}" ]]
then
  log_warn "env var KEYGEN_LICENSE is not set!"

  echo -ne "\033[34mPlease enter a license key: \033[0m"
  read KEYGEN_LICENSE
fi

# Assert jq is installed.
if ! command -v jq &> /dev/null
then
  log_error 'jq command is not installed!'

  exit 1
fi

# Detect current OS.
os="${OS:-$(uname -s | tr '[:upper:]' '[:lower:]')}"

case "${os}"
in
  msys*|mingw*)
    os='windows'
    ;;
  cygwin*)
    os='linux'
    ;;
esac

if [[ -z "${os}" ]]
then
  log_error 'unable to detect operating system'

  exit 1
fi

# Fingerprint current machine.
fingerprint=''

case "${os}"
in
  darwin)
    fingerprint=$(ioreg -d2 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformUUID/{print $(NF-1)}')

    ;;
  linux)
    fingerprint=$(cat /var/lib/dbus/machine-id 2>/dev/null)

    # Fallback to checking the /etc directory.
    if [[ -z "${fingerprint}" ]]
    then
      fingerprint=$(cat /etc/machine-id 2>/dev/null)
    fi

    ;;
  *bsd)
    fingerprint=$(cat /etc/hostid 2>/dev/null)

    ;;
  *)
    log_error "unsupported operating system: ${os}"

    exit 1

    ;;
esac

if [[ -z "${fingerprint}" ]]
then
  log_error 'unable to fingerprint machine'

  exit 1
fi

# Hash the fingerprint, to anonymize it.
fingerprint=$(echo -n "$fingerprint" | shasum -a 256 | head -c 64)

# Validate the license, scoped to the current machine's fingerprint.
read -r code id <<<$(
  curl -s -X POST "https://api.keygen.sh/v1/accounts/${KEYGEN_ACCOUNT}/licenses/${KEYGEN_LICENSE}/actions/validate" \
    -H "Authorization: License ${KEYGEN_LICENSE}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -H 'Keygen-Version: 1.2' \
    -d '{
          "meta": {
            "scope": { "fingerprint": "'$fingerprint'" }
          }
        }' | jq '.meta.code, .data.id' --raw-output
)

case "${code}"
in
  # When license is already valid, that means the machine has already been activated.
  VALID)
    log_info "license ${id} is already activated!"

    exit 0

    ;;
  # Otherwise, attempt to activate the machine.
  FINGERPRINT_SCOPE_MISMATCH|NO_MACHINES|NO_MACHINE)
    log_debug "license ${id} has not been activated yet!"
    log_debug 'activating...'

    debug=$(mktemp)
    status=$(
      curl -s -X POST "https://api.keygen.sh/v1/accounts/${KEYGEN_ACCOUNT}/machines" \
        -H "Authorization: License ${KEYGEN_LICENSE}" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        -H 'Keygen-Version: 1.2' \
        -w '%{http_code}' \
        -o "$debug" \
        -d '{
              "data": {
                "type": "machines",
                "attributes": {
                  "fingerprint": "'$fingerprint'",
                  "platform": "'$os'"
                },
                "relationships": {
                  "license": {
                    "data": { "type": "licenses", "id": "'$id'" }
                  }
                }
              }
            }'
    )

    if [[ "$status" -eq 201 ]]
    then
      log_info "license ${id} has been activated!"

      exit 0
    fi

    log_error "license activation failed: ${status}"
    log_debug "$(cat $debug | jq -Mc '.errors[] | [.detail, .code]')"

    exit 1

    ;;
  *)
    log_error "License is invalid: ${code}"

    exit 1

    ;;
esac
