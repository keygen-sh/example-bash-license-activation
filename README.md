# Example Bash License Activation

This is an example of activating a license key using Bash. You can
utilize this script to, for example, activate a container during a
startup routine (e.g. from `wait-for-it.sh`). This example app
requires [`jq`](https://stedolan.github.io/jq/).

**If you're running this example in a container or other virtualized
environment**: We recommend using a random value, such as a secure
UUID, for fingerprinting, rather than using the container's GUID,
since that can be spoofed, or it may match multiple containers.
When using a random fingerprint, we also recommend deactivating
the machine on shutdown, and monitoring the machine's heartbeat
in case of crashes.

## Running the example

First up, add an environment variable containing your public key:

```bash
# Your Keygen account identifier
export KEYGEN_ACCOUNT='<your keygen account id>'
```

You can either run each line above within your terminal session before
starting the app, or you can add the above contents to your `~/.bashrc`
file and then run `source ~/.bashrc` after saving the file.

Next, grant the `main.sh` bash script execute privileges:

```bash
chmod +x main.sh
```

Then run the script, entering a license key when prompted:

```bash
./main.sh
```

Or pass via an env variable:

```bash
KEYGEN_LICENSE='CEE13F-C888B5-B26A85-2B3336-B01610-V3' \
  KEYGEN_ACCOUNT='demo' ./main.sh
```

The license key will be validated, and if needed, the current machine will
be fingerprinted and activated.

## Questions?

Reach out at [support@keygen.sh](mailto:support@keygen.sh) if you have any
questions or concerns!
