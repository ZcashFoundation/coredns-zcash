#!/bin/bash
#
# Deploy DNS Seeder VMs across multiple GCP zones
#
# This script creates e2-micro VMs running the Zcash DNS seeder container
# across US and European zones for geographic distribution.
#
# Usage:
#   ./deploy-seeders.sh              # Deploy all seeders
#   ./deploy-seeders.sh --dry-run    # Preview commands without executing
#   ./deploy-seeders.sh --status     # Check status of all seeders
#   ./deploy-seeders.sh --dns        # Output DNS configuration only
#
set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

PROJECT="ecosystem-infrastructure"
MACHINE_TYPE="e2-micro"
DISK_SIZE="10"
IMAGE_FAMILY="cos-stable"
IMAGE_PROJECT="cos-cloud"
NETWORK_TAG="seeder"
SERVICE_ACCOUNT="instance-service-account@ecosystem-infrastructure.iam.gserviceaccount.com"

# Container image (same as existing VM)
CONTAINER_IMAGE="us-docker.pkg.dev/zfnd-dev-services/ecosystem-services/dns-seeder@sha256:28496783855af5f6291519f70fec4958d280b00840bbbe487af38c1e7bd362af"

# VM definitions: name|zone|region
# Note: zfnd-seeder-1 (us-central1-a) already exists
declare -a SEEDERS=(
    "zfnd-seeder-2|us-east1-b|us-east1"
    "zfnd-seeder-3|us-west1-a|us-west1"
    "zfnd-seeder-4|europe-west1-b|europe-west1"
    "zfnd-seeder-5|europe-west3-a|europe-west3"
    "zfnd-seeder-6|europe-north1-a|europe-north1"
)

# Existing seeder (for DNS output)
EXISTING_SEEDER="zfnd-seeder-6d3a819|us-central1-a|us-central1|zfnd-seeder-1"

# =============================================================================
# Startup Script (prepares host for DNS seeder container)
# =============================================================================

read -r -d '' STARTUP_SCRIPT << 'STARTUP_EOF' || true
#!/bin/bash
# Stop systemd-resolved to free up port 53
systemctl stop systemd-resolved

# Ensure DNS resolution works by adding Google DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
STARTUP_EOF

# =============================================================================
# Container Declaration (for GCE container VM)
# =============================================================================

generate_container_declaration() {
    local name="$1"
    cat <<CONTAINER_EOF
spec:
  restartPolicy: Always
  containers:
  - name: ${name}
    image: ${CONTAINER_IMAGE}
    # Uses built-in Corefile from Docker image
    securityContext:
      privileged: true
    stdin: true
    tty: true
CONTAINER_EOF
}

# =============================================================================
# Helper Functions
# =============================================================================

DRY_RUN=false
STATUS_ONLY=false
DNS_ONLY=false

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $*"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $*"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*"
}

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "\033[0;36m[DRY-RUN]\033[0m $*"
    else
        "$@"
    fi
}

# Check if a static IP exists
ip_exists() {
    local name="$1"
    local region="$2"
    gcloud compute addresses describe "$name" \
        --project="$PROJECT" \
        --region="$region" \
        --format="value(name)" 2>/dev/null || echo ""
}

# Get IP address value
get_ip_address() {
    local name="$1"
    local region="$2"
    gcloud compute addresses describe "$name" \
        --project="$PROJECT" \
        --region="$region" \
        --format="value(address)" 2>/dev/null || echo ""
}

# Check if a VM exists
vm_exists() {
    local name="$1"
    local zone="$2"
    gcloud compute instances describe "$name" \
        --project="$PROJECT" \
        --zone="$zone" \
        --format="value(name)" 2>/dev/null || echo ""
}

# Get VM status
get_vm_status() {
    local name="$1"
    local zone="$2"
    gcloud compute instances describe "$name" \
        --project="$PROJECT" \
        --zone="$zone" \
        --format="value(status)" 2>/dev/null || echo "NOT_FOUND"
}

# =============================================================================
# Deployment Functions
# =============================================================================

create_static_ip() {
    local name="$1"
    local region="$2"
    
    if [ -n "$(ip_exists "$name" "$region")" ]; then
        log_info "Static IP '$name' already exists in $region"
        return 0
    fi
    
    log_info "Creating static IP '$name' in $region..."
    run_cmd gcloud compute addresses create "$name" \
        --project="$PROJECT" \
        --region="$region" \
        --network-tier=PREMIUM
}

create_vm() {
    local name="$1"
    local zone="$2"
    local region="$3"
    local ip_name="$name"
    
    if [ -n "$(vm_exists "$name" "$zone")" ]; then
        log_info "VM '$name' already exists in $zone"
        return 0
    fi
    
    # Get the static IP address
    local ip_address
    ip_address=$(get_ip_address "$ip_name" "$region")
    
    if [ "$DRY_RUN" = true ]; then
        log_info "Would create VM '$name' with:"
        echo "  - Zone: $zone"
        echo "  - Machine type: $MACHINE_TYPE"
        echo "  - Static IP: ${ip_address:-<will be created>}"
        echo "  - Container image: $CONTAINER_IMAGE"
        return 0
    fi
    
    if [ -z "$ip_address" ]; then
        log_error "Static IP '$ip_name' not found in $region. Create it first."
        return 1
    fi
    
    log_info "Creating VM '$name' in $zone with IP $ip_address..."
    
    # Create temporary files for metadata
    local container_file
    local startup_file
    container_file=$(mktemp)
    startup_file=$(mktemp)
    
    generate_container_declaration "$name" > "$container_file"
    echo "$STARTUP_SCRIPT" > "$startup_file"
    
    gcloud compute instances create "$name" \
        --project="$PROJECT" \
        --zone="$zone" \
        --machine-type="$MACHINE_TYPE" \
        --network-interface="network-tier=PREMIUM,address=$ip_address,stack-type=IPV4_ONLY" \
        --metadata-from-file="gce-container-declaration=$container_file,startup-script=$startup_file" \
        --metadata="google-logging-enabled=true" \
        --maintenance-policy=MIGRATE \
        --provisioning-model=STANDARD \
        --service-account="$SERVICE_ACCOUNT" \
        --scopes="https://www.googleapis.com/auth/cloud-platform" \
        --tags="$NETWORK_TAG" \
        --create-disk="auto-delete=yes,boot=yes,device-name=$name,image-family=$IMAGE_FAMILY,image-project=$IMAGE_PROJECT,mode=rw,size=$DISK_SIZE,type=pd-balanced" \
        --labels="container-vm=$name" \
        --deletion-protection \
        --no-shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring
    
    rm -f "$container_file" "$startup_file"
    
    log_info "VM '$name' created successfully"
}

# =============================================================================
# Status and DNS Functions
# =============================================================================

show_status() {
    echo ""
    echo "======================================================================"
    echo "DNS Seeder Status"
    echo "======================================================================"
    echo ""
    printf "%-20s %-18s %-15s %-15s\n" "NAME" "ZONE" "STATUS" "EXTERNAL_IP"
    printf "%-20s %-18s %-15s %-15s\n" "----" "----" "------" "-----------"
    
    # Existing seeder
    IFS='|' read -r name zone region ip_name <<< "$EXISTING_SEEDER"
    local status
    status=$(get_vm_status "$name" "$zone")
    local ip
    ip=$(get_ip_address "$ip_name" "$region")
    printf "%-20s %-18s %-15s %-15s\n" "$name" "$zone" "$status" "$ip"
    
    # New seeders
    for seeder in "${SEEDERS[@]}"; do
        IFS='|' read -r name zone region <<< "$seeder"
        status=$(get_vm_status "$name" "$zone")
        ip=$(get_ip_address "$name" "$region")
        printf "%-20s %-18s %-15s %-15s\n" "$name" "$zone" "$status" "${ip:-N/A}"
    done
    echo ""
}

output_dns_config() {
    echo ""
    echo "======================================================================"
    echo "DNS Configuration for Round-Robin"
    echo "======================================================================"
    echo ""
    echo "; Add the following A records to your DNS zone for seeder.zfnd.org"
    echo "; This enables DNS round-robin load balancing across all seeders"
    echo ""
    
    declare -a all_ips=()
    
    # Existing seeder IP
    IFS='|' read -r _ _ region ip_name <<< "$EXISTING_SEEDER"
    local ip
    ip=$(get_ip_address "$ip_name" "$region")
    if [ -n "$ip" ]; then
        all_ips+=("$ip")
    fi
    
    # New seeder IPs
    for seeder in "${SEEDERS[@]}"; do
        IFS='|' read -r name _ region <<< "$seeder"
        ip=$(get_ip_address "$name" "$region")
        if [ -n "$ip" ]; then
            all_ips+=("$ip")
        fi
    done
    
    echo "; Mainnet seeder records"
    for ip in "${all_ips[@]}"; do
        echo "mainnet.seeder.zfnd.org.    IN    A    $ip"
    done
    
    echo ""
    echo "; Testnet seeder records"
    for ip in "${all_ips[@]}"; do
        echo "testnet.seeder.zfnd.org.    IN    A    $ip"
    done
    
    echo ""
    echo "; NS delegation (if using subdomain delegation)"
    echo "; seeder.zfnd.org.    IN    NS    ns1.your-dns-provider.com."
    echo ""
    
    echo "======================================================================"
    echo "Verification Commands"
    echo "======================================================================"
    echo ""
    echo "# Test each seeder individually:"
    for ip in "${all_ips[@]}"; do
        echo "dig @$ip mainnet.seeder.zfnd.org +short"
    done
    echo ""
}

# =============================================================================
# Main
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --status)
                STATUS_ONLY=true
                shift
                ;;
            --dns)
                DNS_ONLY=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --dry-run    Preview commands without executing"
                echo "  --status     Show status of all seeders"
                echo "  --dns        Output DNS configuration only"
                echo "  --help       Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    
    if [ "$STATUS_ONLY" = true ]; then
        show_status
        exit 0
    fi
    
    if [ "$DNS_ONLY" = true ]; then
        output_dns_config
        exit 0
    fi
    
    echo ""
    echo "======================================================================"
    echo "Deploying DNS Seeders"
    echo "======================================================================"
    echo ""
    echo "Project:       $PROJECT"
    echo "Machine Type:  $MACHINE_TYPE"
    echo "Dry Run:       $DRY_RUN"
    echo ""
    
    # Deploy each seeder
    for seeder in "${SEEDERS[@]}"; do
        IFS='|' read -r name zone region <<< "$seeder"
        
        echo ""
        echo "----------------------------------------------------------------------"
        echo "Deploying $name in $zone ($region)"
        echo "----------------------------------------------------------------------"
        
        # Create static IP first
        create_static_ip "$name" "$region"
        
        # Create VM
        create_vm "$name" "$zone" "$region"
    done
    
    echo ""
    echo "======================================================================"
    echo "Deployment Complete"
    echo "======================================================================"
    
    # Show status
    show_status
    
    # Output DNS config
    output_dns_config
}

main "$@"
