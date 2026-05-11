#!/usr/bin/env bash
#
# dns-toolkit.sh — Utilidades DNS interactivas
# Uso: ./dns-toolkit.sh [opción] [dominio/IP]
#

set -euo pipefail

DOMAIN=""

# ── Colores ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Funciones auxiliares ─────────────────────────────────────────────

print_header() {
    echo -e "\n${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}\n"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        print_error "El comando '$1' no está instalado."
        echo "  Instálalo con: sudo apt install $2"
        return 1
    fi
}

ask_domain() {
    if [[ -n "${DOMAIN:-}" ]]; then
        return 0
    fi
    local prompt="${1:-Ingresa el dominio}"
    read -rp "$(echo -e "${YELLOW}${prompt}: ${NC}")" DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        print_error "No ingresaste un valor."
        return 1
    fi
}

# ── 1. Resolución de registros DNS ───────────────────────────────────

dns_lookup() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio a consultar" || return

    print_header "Registros DNS para: $DOMAIN"

    local tipos=("A" "AAAA" "MX" "NS" "TXT" "CNAME" "SOA")
    for tipo in "${tipos[@]}"; do
        echo -e "${BOLD}── $tipo ──${NC}"
        resultado=$(dig +short "$DOMAIN" "$tipo" 2>/dev/null)
        if [[ -n "$resultado" ]]; then
            echo "$resultado"
        else
            echo -e "  ${YELLOW}(sin resultados)${NC}"
        fi
        echo
    done
}

# ── 2. Lookup de un tipo específico ──────────────────────────────────

dns_lookup_tipo() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio" || return

    echo -e "${YELLOW}Tipos disponibles: A, AAAA, MX, NS, TXT, CNAME, SOA, SRV, PTR, CAA${NC}"
    read -rp "$(echo -e "${YELLOW}Tipo de registro: ${NC}")" TIPO
    TIPO="${TIPO^^}"

    print_header "Registro $TIPO para: $DOMAIN"
    dig +noall +answer "$DOMAIN" "$TIPO" 2>/dev/null || print_error "Consulta fallida."
}

# ── 3. Lookup inverso (IP → dominio) ────────────────────────────────

dns_reverse() {
    check_command dig dnsutils || return
    ask_domain "Ingresa la dirección IP" || return

    print_header "Lookup inverso para: $DOMAIN"
    resultado=$(dig +short -x "$DOMAIN" 2>/dev/null)
    if [[ -n "$resultado" ]]; then
        print_info "Hostname: $resultado"
    else
        print_warn "No se encontró registro PTR para $DOMAIN"
    fi
}

# ── 4. Verificar propagación DNS ────────────────────────────────────

dns_propagation() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio a verificar" || return

    print_header "Propagación DNS para: $DOMAIN"

    local servidores=(
        "8.8.8.8:Google"
        "8.8.4.4:Google-2"
        "1.1.1.1:Cloudflare"
        "1.0.0.1:Cloudflare-2"
        "9.9.9.9:Quad9"
        "208.67.222.222:OpenDNS"
        "208.67.220.220:OpenDNS-2"
        "76.76.2.0:ControlD"
    )

    printf "${BOLD}%-20s %-15s %s${NC}\n" "Servidor DNS" "Proveedor" "Resultado"
    echo "────────────────────────────────────────────────────"

    for entry in "${servidores[@]}"; do
        IFS=':' read -r ip nombre <<< "$entry"
        resultado=$(dig +short "$DOMAIN" A "@$ip" 2>/dev/null | head -1)
        if [[ -n "$resultado" ]]; then
            printf "%-20s %-15s ${GREEN}%s${NC}\n" "$ip" "$nombre" "$resultado"
        else
            printf "%-20s %-15s ${RED}%s${NC}\n" "$ip" "$nombre" "(sin respuesta)"
        fi
    done
}

# ── 5. Whois ─────────────────────────────────────────────────────────

dns_whois() {
    check_command whois whois || return
    ask_domain "Ingresa el dominio o IP" || return

    print_header "Whois para: $DOMAIN"
    whois "$DOMAIN" 2>/dev/null || print_error "Consulta whois fallida."
}

# ── 6. Trace DNS (seguir delegación) ────────────────────────────────

dns_trace() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio" || return

    print_header "Trace DNS para: $DOMAIN"
    dig +trace "$DOMAIN" 2>/dev/null || print_error "Trace fallido."
}

# ── 7. Servidores de nombres autoritativos ───────────────────────────

dns_nameservers() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio" || return

    print_header "Servidores autoritativos para: $DOMAIN"

    ns_list=$(dig +short "$DOMAIN" NS 2>/dev/null)
    if [[ -z "$ns_list" ]]; then
        print_warn "No se encontraron registros NS."
        return
    fi

    while IFS= read -r ns; do
        ip=$(dig +short "$ns" A 2>/dev/null | head -1)
        printf "  ${GREEN}%-30s${NC} → %s\n" "$ns" "${ip:-(sin IP)}"
    done <<< "$ns_list"
}

# ── 8. Verificar zona de transferencia (AXFR) ───────────────────────

dns_axfr() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio" || return

    print_header "Intento de transferencia de zona (AXFR) para: $DOMAIN"
    print_warn "Nota: la mayoría de servidores bloquean AXFR por seguridad."

    ns_list=$(dig +short "$DOMAIN" NS 2>/dev/null)
    if [[ -z "$ns_list" ]]; then
        print_error "No se encontraron servidores NS."
        return
    fi

    while IFS= read -r ns; do
        echo -e "\n${BOLD}Probando: $ns${NC}"
        resultado=$(dig AXFR "$DOMAIN" "@$ns" 2>/dev/null)
        if echo "$resultado" | grep -q "Transfer failed"; then
            print_info "AXFR bloqueado por $ns (esperado)."
        elif [[ -n "$resultado" ]]; then
            echo "$resultado"
        else
            print_info "Sin respuesta de $ns."
        fi
    done <<< "$ns_list"
}

# ── 9. Comparar respuestas entre servidores DNS ─────────────────────

dns_compare() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio" || return

    print_header "Comparación de respuestas DNS para: $DOMAIN"

    local servidores=("8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222")

    printf "${BOLD}%-18s %-20s %s${NC}\n" "Servidor" "IP Resultado" "TTL"
    echo "────────────────────────────────────────────────────"

    for dns in "${servidores[@]}"; do
        linea=$(dig +noall +answer "$DOMAIN" A "@$dns" 2>/dev/null | head -1)
        if [[ -n "$linea" ]]; then
            ip=$(echo "$linea" | awk '{print $5}')
            ttl=$(echo "$linea" | awk '{print $2}')
            printf "%-18s %-20s %s seg\n" "$dns" "$ip" "$ttl"
        else
            printf "%-18s ${RED}%-20s${NC} %s\n" "$dns" "(sin respuesta)" "-"
        fi
    done
}

# ── 10. Registros de seguridad (SPF, DKIM, DMARC) ───────────────────

dns_security() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio" || return

    print_header "Registros de seguridad de email para: $DOMAIN"

    echo -e "${BOLD}── SPF ──${NC}"
    spf=$(dig +short "$DOMAIN" TXT 2>/dev/null | grep -i "spf" || true)
    if [[ -n "$spf" ]]; then
        echo "  $spf"
    else
        print_warn "No se encontró registro SPF."
    fi

    echo -e "\n${BOLD}── DMARC ──${NC}"
    dmarc=$(dig +short "_dmarc.$DOMAIN" TXT 2>/dev/null || true)
    if [[ -n "$dmarc" ]]; then
        echo "  $dmarc"
    else
        print_warn "No se encontró registro DMARC."
    fi

    echo -e "\n${BOLD}── DKIM (selector: default) ──${NC}"
    dkim=$(dig +short "default._domainkey.$DOMAIN" TXT 2>/dev/null || true)
    if [[ -n "$dkim" ]]; then
        echo "  $dkim"
    else
        print_warn "No se encontró DKIM con selector 'default'."
        echo "  Prueba con otros selectores comunes: google, selector1, selector2, k1"
    fi

    echo -e "\n${BOLD}── CAA ──${NC}"
    caa=$(dig +short "$DOMAIN" CAA 2>/dev/null || true)
    if [[ -n "$caa" ]]; then
        echo "  $caa"
    else
        print_warn "No se encontró registro CAA."
    fi
}

# ── 11. Información completa de un dominio ───────────────────────────

dns_full_report() {
    check_command dig dnsutils || return
    ask_domain "Ingresa el dominio" || return

    print_header "Reporte completo DNS para: $DOMAIN"

    local tipos=("A" "AAAA" "MX" "NS" "TXT" "CNAME" "SOA" "CAA" "SRV")
    for tipo in "${tipos[@]}"; do
        echo -e "${BOLD}── $tipo ──${NC}"
        dig +noall +answer "$DOMAIN" "$tipo" 2>/dev/null || echo "  (error)"
        echo
    done

    echo -e "${BOLD}── Servidores NS (con IPs) ──${NC}"
    ns_list=$(dig +short "$DOMAIN" NS 2>/dev/null)
    while IFS= read -r ns; do
        [[ -z "$ns" ]] && continue
        ip=$(dig +short "$ns" A 2>/dev/null | head -1)
        printf "  %-30s → %s\n" "$ns" "${ip:-(sin IP)}"
    done <<< "$ns_list"
}

# ── Menú interactivo ─────────────────────────────────────────────────

show_menu() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}         🌐 DNS Toolkit — Menú Principal         ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}1)${NC}  Consulta DNS completa (todos los registros)  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}2)${NC}  Consulta por tipo de registro               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}3)${NC}  Lookup inverso (IP → dominio)               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}4)${NC}  Verificar propagación DNS                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}5)${NC}  Whois                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}6)${NC}  Trace DNS (seguir delegación)                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}7)${NC}  Servidores de nombres autoritativos          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}8)${NC}  Transferencia de zona (AXFR)                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}9)${NC}  Comparar respuestas entre DNS                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}10)${NC} Registros de seguridad (SPF/DKIM/DMARC)      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}11)${NC} Reporte completo de un dominio               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${RED}0)${NC}  Salir                                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
}

# ── Uso directo desde línea de comandos ──────────────────────────────

usage() {
    echo "Uso: $0 [opción] [dominio/IP]"
    echo
    echo "Opciones:"
    echo "  lookup   <dominio>   Consulta DNS completa"
    echo "  type     <dominio>   Consulta por tipo"
    echo "  reverse  <IP>        Lookup inverso"
    echo "  propagation <dom>    Verificar propagación"
    echo "  whois    <dominio>   Whois"
    echo "  trace    <dominio>   Trace DNS"
    echo "  ns       <dominio>   Servidores autoritativos"
    echo "  axfr     <dominio>   Transferencia de zona"
    echo "  compare  <dominio>   Comparar servidores DNS"
    echo "  security <dominio>   Registros SPF/DKIM/DMARC"
    echo "  report   <dominio>   Reporte completo"
    echo
    echo "Sin argumentos: modo interactivo"
}

# ── Ejecución desde CLI ──────────────────────────────────────────────

if [[ $# -ge 1 ]]; then
    DOMAIN="${2:-}"
    case "$1" in
        lookup)      dns_lookup ;;
        type)        dns_lookup_tipo ;;
        reverse)     dns_reverse ;;
        propagation) dns_propagation ;;
        whois)       dns_whois ;;
        trace)       dns_trace ;;
        ns)          dns_nameservers ;;
        axfr)        dns_axfr ;;
        compare)     dns_compare ;;
        security)    dns_security ;;
        report)      dns_full_report ;;
        -h|--help)   usage ;;
        *)           print_error "Opción desconocida: $1"; usage; exit 1 ;;
    esac
    exit 0
fi

# ── Modo interactivo ─────────────────────────────────────────────────

while true; do
    show_menu
    read -rp "$(echo -e "${YELLOW}Selecciona una opción: ${NC}")" opcion
    DOMAIN=""
    case "$opcion" in
        1)  dns_lookup ;;
        2)  dns_lookup_tipo ;;
        3)  dns_reverse ;;
        4)  dns_propagation ;;
        5)  dns_whois ;;
        6)  dns_trace ;;
        7)  dns_nameservers ;;
        8)  dns_axfr ;;
        9)  dns_compare ;;
        10) dns_security ;;
        11) dns_full_report ;;
        0)  echo -e "\n${GREEN}¡Hasta luego!${NC}\n"; exit 0 ;;
        *)  print_error "Opción inválida." ;;
    esac
    echo
    read -rp "$(echo -e "${YELLOW}Presiona Enter para continuar...${NC}")"
done
