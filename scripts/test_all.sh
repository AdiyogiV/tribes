#!/bin/bash

# =============================================================================
# AUROGRAM UNIFIED TEST SUITE
# =============================================================================
#
# Tests BOTH frontend (Flutter) and backend (Node.js) in one command.
#
# Usage:
#   ./scripts/test_all.sh              # Run all tests
#   ./scripts/test_all.sh --frontend   # Flutter tests only  
#   ./scripts/test_all.sh --backend    # Backend tests only
#   ./scripts/test_all.sh --json       # JSON output for CI/CD
#
# Exit codes:
#   0 - All tests passed
#   1 - Some tests failed
#
# =============================================================================

set -e

cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Configuration
OUTPUT_FORMAT="human"
RUN_FRONTEND=true
RUN_BACKEND=true
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Results
FRONTEND_PASSED=0
FRONTEND_FAILED=0
BACKEND_PASSED=0
BACKEND_FAILED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --frontend) RUN_BACKEND=false ;;
        --backend)  RUN_FRONTEND=false ;;
        --json)     OUTPUT_FORMAT="json" ;;
        --help)
            echo "Usage: ./scripts/test_all.sh [--frontend|--backend|--json]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# =============================================================================
# OUTPUT
# =============================================================================

log_header() {
    [[ "$OUTPUT_FORMAT" != "human" ]] && return
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 AUROGRAM UNIFIED TEST SUITE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 $PROJECT_ROOT"
    echo "⏰ $TIMESTAMP"
}

log_section() {
    [[ "$OUTPUT_FORMAT" != "human" ]] && return
    echo ""
    echo "─── $1 ───"
}

log_result() {
    [[ "$OUTPUT_FORMAT" != "human" ]] && return
    local icon=$([[ "$2" == "true" ]] && echo "✓" || echo "✗")
    echo "  $icon $1"
}

log_summary() {
    local frontend_total=$((FRONTEND_PASSED + FRONTEND_FAILED))
    local backend_total=$((BACKEND_PASSED + BACKEND_FAILED))
    local total=$((frontend_total + backend_total))
    local passed=$((FRONTEND_PASSED + BACKEND_PASSED))
    local failed=$((FRONTEND_FAILED + BACKEND_FAILED))
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "project": "$PROJECT_ROOT",
  "summary": {
    "total": $total,
    "passed": $passed,
    "failed": $failed
  },
  "frontend": {
    "total": $frontend_total,
    "passed": $FRONTEND_PASSED,
    "failed": $FRONTEND_FAILED
  },
  "backend": {
    "total": $backend_total,
    "passed": $BACKEND_PASSED,
    "failed": $BACKEND_FAILED
  },
  "success": $([ $failed -eq 0 ] && echo "true" || echo "false")
}
EOF
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 UNIFIED TEST RESULTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if [[ $RUN_FRONTEND == true ]]; then
            echo "  📱 Frontend: $FRONTEND_PASSED passed, $FRONTEND_FAILED failed"
        fi
        if [[ $RUN_BACKEND == true ]]; then
            echo "  ☁️  Backend:  $BACKEND_PASSED passed, $BACKEND_FAILED failed"
        fi
        
        echo "  ─────────────────────────────────────"
        echo "  📈 Total:    $passed passed, $failed failed"
        echo ""
        
        if [ $failed -eq 0 ]; then
            echo "✅ ALL TESTS PASSED"
        else
            echo "❌ SOME TESTS FAILED"
        fi
        echo ""
    fi
}

# =============================================================================
# FRONTEND TESTS (Flutter)
# =============================================================================

run_frontend_tests() {
    log_section "📱 Frontend Tests (Flutter)"
    
    local output
    local exit_code=0
    
    # Run flutter tests
    output=$(flutter test 2>&1) || exit_code=$?
    
    if echo "$output" | grep -q "All tests passed"; then
        # Count tests from output
        local count=$(echo "$output" | grep -oE '\+[0-9]+:' | tail -1 | grep -oE '[0-9]+' || echo "0")
        FRONTEND_PASSED=$count
        log_result "Flutter tests ($count tests)" "true"
    else
        FRONTEND_FAILED=1
        log_result "Flutter tests" "false"
        
        if [[ "$OUTPUT_FORMAT" == "human" ]]; then
            echo ""
            echo "  Failures:"
            echo "$output" | grep -E "(FAILED|Error:|✗)" | head -5 | sed 's/^/    /'
        fi
    fi
    
    return $exit_code
}

# =============================================================================
# BACKEND TESTS (Node.js)
# =============================================================================

run_backend_tests() {
    log_section "☁️  Backend Tests (Node.js)"
    
    if [ ! -d "backend" ]; then
        [[ "$OUTPUT_FORMAT" == "human" ]] && echo "  (skipped - no backend directory)"
        return 0
    fi
    
    cd backend
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        [[ "$OUTPUT_FORMAT" == "human" ]] && echo "  Installing dependencies..."
        npm install --silent 2>/dev/null || npm install
    fi
    
    local output
    local exit_code=0
    
    # Run backend tests
    if [ -f "tests/test_all.js" ]; then
        output=$(node tests/test_all.js 2>&1) || exit_code=$?
        
        if echo "$output" | grep -q "All backend tests passed"; then
            # Extract pass count
            local count=$(echo "$output" | grep -oE 'Passed:\s+[0-9]+' | grep -oE '[0-9]+' || echo "0")
            BACKEND_PASSED=$count
            log_result "Backend tests ($count tests)" "true"
        else
            # Extract fail count
            local failed=$(echo "$output" | grep -oE 'Failed:\s+[0-9]+' | grep -oE '[0-9]+' || echo "1")
            local passed=$(echo "$output" | grep -oE 'Passed:\s+[0-9]+' | grep -oE '[0-9]+' || echo "0")
            BACKEND_PASSED=$passed
            BACKEND_FAILED=$failed
            log_result "Backend tests" "false"
            
            if [[ "$OUTPUT_FORMAT" == "human" ]]; then
                echo ""
                echo "  Failures:"
                echo "$output" | grep -E "✗|❌|FAIL" | head -5 | sed 's/^/    /'
            fi
        fi
    else
        [[ "$OUTPUT_FORMAT" == "human" ]] && echo "  (no test_all.js found)"
    fi
    
    cd "$PROJECT_ROOT"
    return $exit_code
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_header
    
    local exit_code=0
    
    if [[ $RUN_FRONTEND == true ]]; then
        run_frontend_tests || exit_code=1
    fi
    
    if [[ $RUN_BACKEND == true ]]; then
        run_backend_tests || exit_code=1
    fi
    
    log_summary
    
    exit $exit_code
}

main
