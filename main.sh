#!/bin/bash

set -e

export PATH=$PATH:/usr/games:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export PATH_SEC="$SCRIPT_DIR/secure_env_data/secure_container.img"
export NAME="secure_env"
export MOUNT="/mnt/$NAME"
export SIZE="5G"

export cle_gpg_dir="$MOUNT/gpg_cles"
export SSH_COFFRE_DIR="$MOUNT/ssh"

export ERREUR="\e[31m[ERREUR]\e[0m"

source "$SCRIPT_DIR/lib/install.sh"
source "$SCRIPT_DIR/lib/setup.sh"
source "$SCRIPT_DIR/lib/cryptogpg.sh"
source "$SCRIPT_DIR/lib/ssh_config_manager.sh"


display_help() {
    echo "Utilisation : $0 [ACTION]"
    echo
    echo "Actions disponibles :"
    echo "  install : Met en place et chiffre l'environnement sécurisé"
    echo "  open : Ouvre et monte l'environnement sécurisé"
    echo "  close : Ferme et démonte l'environnement sécurisé"
    echo "  gpg_create : Crée une nouvelle paire de clés GPG dans le coffre"
    echo "  gpg_export_pub : Exporte une clé publique GPG de votre trousseau vers le coffre"
    echo "  gpg_export_priv : Exporte une clé privée GPG de votre trousseau vers le coffre"
    echo "  gpg_import_vault : Importe les clés GPG du coffre vers votre trousseau"
    echo "  gpg_export_vault : Exporte les clés GPG de votre trousseau vers le coffre"
    echo "  ssh_setup : Crée le template de config SSH et configure l'alias"
    echo "  ssh_import : Importe des configs et clés SSH existantes dans le coffre"
    echo "  set_permissions : Définit les permissions et attributs sécurisés dans le coffre"
    echo
    cowsay "Choisissez votre action !"
}

if [ $# -eq 0 ]; then
    display_help
    exit 1
fi

ACTION=$1

check_dependencies() {
    install_figlet
    install_cowsay
    install_cryptsetup
}

check_dependencies

case "$ACTION" in
    install)
        setup_env
        ;;
    open)
        open_env
        set_secure_permissions
        ;;
    close)
        close_env
        ;;
    gpg_create)
        if ! mountpoint -q "$MOUNT"; then
            echo -e "$ERREUR L'environnement sécurisé n'est pas monté ($MOUNT). Veuillez l'ouvrir d'abord."
            exit 1
        fi
        gpg_create_cles
        ;;
    gpg_export_pub)
        if ! mountpoint -q "$MOUNT"; then echo -e "$ERREUR Environnement non monté."; exit 1; fi
        gpg_exportation_cle_public
        ;;
    gpg_export_priv)
        if ! mountpoint -q "$MOUNT"; then echo -e "$ERREUR Environnement non monté."; exit 1; fi
        gpg_exportation_cle_privee
        ;;
    gpg_import_vault)
        if ! mountpoint -q "$MOUNT"; then echo -e "$ERREUR Environnement non monté."; exit 1; fi
        gpg_importation_depuis_coffre
        ;;
    gpg_export_vault)
        if ! mountpoint -q "$MOUNT"; then echo -e "$ERREUR Environnement non monté."; exit 1; fi
        gpg_exportation_vers_coffre
        ;;
    ssh_setup)
        if ! mountpoint -q "$MOUNT"; then echo -e "$ERREUR Environnement non monté."; exit 1; fi
        creation_ssh_config_template
        configuration_aliases
        ;;
    ssh_import)
        if ! mountpoint -q "$MOUNT"; then echo -e "$ERREUR Environnement non monté."; exit 1; fi
        importation_ssh_config
        set_secure_permissions
        ;;
    set_permissions)
        if ! mountpoint -q "$MOUNT"; then echo -e "$ERREUR Environnement non monté."; exit 1; fi
        set_secure_permissions
        ;;
    *)
        cowsay "Action inconnue : $ACTION"
        display_help
        exit 1
        ;;
esac