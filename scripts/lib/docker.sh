#!/bin/bash
# =============================================================================
# docker.sh — Docker Compose lifecycle for Matrix test infrastructure
# =============================================================================

# Start the Matrix test infrastructure (Postgres + Synapse + Redis + init)
docker_start_services() {
    local compose_file="${PROJECT_ROOT:-.}/docker-compose.yml"

    if [[ ! -f "$compose_file" ]]; then
        log_error "docker-compose.yml not found at $compose_file"
        return 1
    fi

    if ! command -v docker &>/dev/null; then
        log_error "docker not found in PATH"
        return 1
    fi

    log_info "Starting Docker test infrastructure..."

    # Start infrastructure services
    docker compose -f "$compose_file" up -d postgres matrix-synapse redis 2>&1 | tail -10
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "Failed to start Docker services"
        return 1
    fi

    # Wait for Synapse healthcheck
    docker_wait_for_matrix || return 1

    # Run the init container to seed test data
    log_info "Seeding test data..."
    docker compose -f "$compose_file" run --rm matrix-init 2>&1 | tail -5
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_warn "matrix-init may have failed (continuing — data may already exist)"
    fi

    log_success "Docker test infrastructure is ready"
}

# Wait for the Matrix server to respond on its API endpoint
docker_wait_for_matrix() {
    local server="${MATRIX_SERVER:-http://localhost:8008}"
    local max_retries="${MATRIX_WAIT_RETRIES:-30}"
    local retry=0

    log_info "Waiting for Matrix server at $server ..."

    while [[ $retry -lt $max_retries ]]; do
        if curl -sf "${server}/_matrix/client/versions" >/dev/null 2>&1; then
            log_success "Matrix server is ready"
            return 0
        fi
        ((retry++))
        if [[ $((retry % 5)) -eq 0 ]]; then
            log_info "Matrix not ready yet ($retry/$max_retries)..."
        fi
        sleep 2
    done

    log_error "Matrix server did not become ready after $((max_retries * 2))s"
    log_info "Printing matrix-synapse logs for debugging:"
    docker compose -f "$compose_file" logs matrix-synapse | tail -50
    return 1
}

# Stop Docker services and optionally remove volumes
docker_stop_services() {
    local compose_file="${PROJECT_ROOT:-.}/docker-compose.yml"

    if [[ ! -f "$compose_file" ]]; then
        return 0
    fi

    log_info "Stopping Docker test infrastructure..."
    docker compose -f "$compose_file" down -v 2>&1 | tail -5
    log_success "Docker services stopped"
}
