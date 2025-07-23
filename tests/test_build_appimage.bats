#!/usr/bin/env bats
# Tests for build_appimage.sh

load 'setup_suite'

setup() {
    source_script_functions "$PROJECT_ROOT/build_appimage.sh"
    create_mock_command "curl" 0 ""
    create_mock_command "wget" 0 ""
    create_mock_command "sha256sum" 0 "b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2  appimagetool"
}

@test "check_network should return 0 when network is available" {
    run check_network
    [ "$status" -eq 0 ]
}

@test "check_network should return 1 when network is unavailable" {
    create_mock_command "curl" 1 ""
    run check_network
    [ "$status" -eq 1 ]
}

@test "download_appimagetool should download and verify checksums" {
    # Create a temporary file for appimagetool
    touch "$TEST_TEMP_DIR/appimagetool"
    
    # Mock the download and verification
    cat > "$MOCK_BIN_DIR/curl" <<'EOF'
#!/bin/bash
if [[ "$1" == "-L" ]]; then
    touch "$3"  # Create the file
fi
EOF
    chmod +x "$MOCK_BIN_DIR/curl"
    
    cd "$TEST_TEMP_DIR"
    run download_appimagetool
    [ "$status" -eq 0 ]
}

teardown() {
    cd "$PROJECT_ROOT"
}
