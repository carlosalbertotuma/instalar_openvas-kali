#!/bin/bash
## devido a dificuldade de instalar o openvas com os comandos da documentação foi elaborado esse script para automatizar o processo. ###
## By Carlos Tuma - bl4dsc4n


set -e

log() {
    echo -e "\n[+] $1\n"
}

# Verificar se o script está sendo executado como root
if [[ "$EUID" -ne 0 ]]; then
    echo "Por favor, execute como root ou com sudo."
    exit 1
fi

log "Verificando clusters PostgreSQL existentes..."
pg_lsclusters

# Se o cluster 17 existir e o 16 ainda estiver presente, é necessário remover o 17 antes do upgrade
if pg_lsclusters | grep -q "17.*main" && pg_lsclusters | grep -q "16.*main"; then
    log "O cluster 17 já existe e impede a atualização."

    read -p "Deseja remover o cluster 17 para prosseguir com o upgrade? (s/n): " confirm
    if [[ "$confirm" != "s" ]]; then
        log "Operação cancelada pelo usuário."
        exit 1
    fi

    # Parar o cluster 17 se estiver rodando
    if pg_lsclusters | grep "17.*main.*online"; then
        log "Parando cluster PostgreSQL 17..."
        pg_ctlcluster 17 main stop
    fi

    log "Removendo cluster PostgreSQL 17 existente..."
    pg_dropcluster 17 main --stop
fi

# Se o cluster 16 ainda existir, prosseguir com o upgrade
if pg_lsclusters | grep -q "16.*main"; then
    log "Atualizando cluster do PostgreSQL 16 para 17..."
    pg_upgradecluster 16 main
else
    log "Nenhum cluster 16 encontrado. Nada para atualizar."
fi

# Iniciar o cluster 17 se estiver offline
if pg_lsclusters | grep "17.*main.*offline"; then
    log "Iniciando cluster PostgreSQL 17..."
    pg_ctlcluster 17 main start
fi

# Remover cluster 16 após upgrade
if pg_lsclusters | grep -q "16.*main"; then
    log "Removendo cluster antigo (16)..."
    pg_dropcluster 16 main --stop
fi

log "Status final dos clusters:"
pg_lsclusters

log "Executando gvm-setup..."
sudo gvm-setup
