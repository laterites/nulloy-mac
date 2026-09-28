# "Nulloy Mac.app" directory, as a single value
defineReplace(macBundleDir) {
    return($$PROJECT_DIR/$$join(MAC_BUNDLE_NAME, " ").app)
}

defineReplace(fixSlashes) {
    win32:!unix_mingw:1 ~= s,/,\\,g
    return($$1)
}
