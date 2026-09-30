isEmpty(N_CONFIG_FORCE_VERSION) {
    CHANGELOG = $$cat($$SRC_DIR/../ChangeLog)
    VERSION_TOKEN = $$member(CHANGELOG, 1, 1)
    N_VERSION = $$replace(VERSION_TOKEN, ",", "")
} else {
    N_VERSION = $$N_CONFIG_FORCE_VERSION
}

# Nulloy Mac has its own version numbering, independent of upstream Nulloy
N_MAC_VERSION = 0.3.0

