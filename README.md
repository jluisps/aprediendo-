# DNS Toolkit 🌐

Script bash interactivo con utilidades DNS para consultas, diagnóstico y análisis de dominios.

## Requisitos

- **bash** 4.0+
- **dig** (paquete `dnsutils`)
- **whois** (paquete `whois`) — solo para la opción Whois

### Instalación de dependencias (Debian/Ubuntu)

```bash
sudo apt update && sudo apt install -y dnsutils whois
```

## Uso

```bash
# Dar permisos de ejecución
chmod +x dns-toolkit.sh

# Modo interactivo (menú)
./dns-toolkit.sh

# Uso directo desde línea de comandos
./dns-toolkit.sh lookup google.com
./dns-toolkit.sh reverse 8.8.8.8
./dns-toolkit.sh propagation ejemplo.com
./dns-toolkit.sh security gmail.com
./dns-toolkit.sh report github.com
```

## Funcionalidades

| # | Función | Descripción |
|---|---------|-------------|
| 1 | **Consulta DNS completa** | Muestra registros A, AAAA, MX, NS, TXT, CNAME y SOA |
| 2 | **Consulta por tipo** | Consulta un tipo de registro específico |
| 3 | **Lookup inverso** | Resuelve una IP a su hostname (registro PTR) |
| 4 | **Propagación DNS** | Verifica respuestas en 8 servidores DNS públicos |
| 5 | **Whois** | Información de registro del dominio |
| 6 | **Trace DNS** | Sigue la cadena de delegación desde los root servers |
| 7 | **Servidores autoritativos** | Lista los NS del dominio con sus IPs |
| 8 | **Transferencia de zona (AXFR)** | Intenta transferencia de zona en cada NS |
| 9 | **Comparar respuestas** | Compara IP y TTL entre diferentes DNS públicos |
| 10 | **Registros de seguridad** | Verifica SPF, DKIM, DMARC y CAA |
| 11 | **Reporte completo** | Genera un informe con todos los registros del dominio |

## Opciones de línea de comandos

```
./dns-toolkit.sh [opción] [dominio/IP]

Opciones:
  lookup   <dominio>   Consulta DNS completa
  type     <dominio>   Consulta por tipo
  reverse  <IP>        Lookup inverso
  propagation <dom>    Verificar propagación
  whois    <dominio>   Whois
  trace    <dominio>   Trace DNS
  ns       <dominio>   Servidores autoritativos
  axfr     <dominio>   Transferencia de zona
  compare  <dominio>   Comparar servidores DNS
  security <dominio>   Registros SPF/DKIM/DMARC
  report   <dominio>   Reporte completo
```

## Ejemplo

```bash
$ ./dns-toolkit.sh lookup google.com

════════════════════════════════════════════════════
  Registros DNS para: google.com
════════════════════════════════════════════════════

── A ──
142.250.80.46

── MX ──
10 smtp.google.com.

── NS ──
ns1.google.com.
ns2.google.com.
...
```
