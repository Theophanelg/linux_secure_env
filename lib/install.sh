#!/bin/bash

install_figlet() {
    if ! command -v figlet &> /dev/null; then
        echo -e "Installation de figlet..."
        { sudo apt update -y && sudo apt install -y figlet; } || {
            echo -e "$ERREUR Échec de l'installation de figlet."
            exit 1
        }
    fi
}

install_cowsay() {
    if ! command -v cowsay &> /dev/null; then
        echo -e "Installation de cowsay..."
        { sudo apt update -y && sudo apt install -y cowsay; } || {
            echo -e "$ERREUR Échec de l'installation de cowsay."
            exit 1
        }
    fi
}

install_cryptsetup() {
    if ! command -v cryptsetup &> /dev/null; then
        echo -e "Installation de cryptsetup..."
        { sudo apt update -y && sudo apt install -y cryptsetup; } || {
            echo -e "$ERREUR Échec de l'installation de cryptsetup."
            exit 1
        }
    fi
}

set_secure_permissions() {
    echo "--- Définition des permissions et attributs sécurisés ---"
    if ! mountpoint -q "$MOUNT"; then
        echo -e "$ERREUR L'environnement sécurisé n'est pas monté ($MOUNT)"
        exit 1
    fi

    mkdir -p "$cle_gpg_dir" 2>/dev/null || true
    mkdir -p "$SSH_COFFRE_DIR" 2>/dev/null || true

    chmod 700 "$MOUNT" || { echo -e "$ERREUR Impossible de définir les permissions pour $MOUNT"; }
    chmod 700 "$cle_gpg_dir" 2>/dev/null || true
    chmod 700 "$SSH_COFFRE_DIR" 2>/dev/null || true

    find "$MOUNT" -type f -name "*_private.asc" -exec chmod 600 {} \; 2>/dev/null || true
    find "$MOUNT" -type f -name "id_rsa*" ! -name "*.pub" -exec chmod 600 {} \; 2>/dev/null || true
    find "$MOUNT" -type f -name "config" -exec chmod 600 {} \; 2>/dev/null || true

    find "$MOUNT" -type f -name "*_public.asc" -exec chmod 644 {} \; 2>/dev/null || true
    find "$MOUNT" -type f -name "*.pub" -exec chmod 644 {} \; 2>/dev/null || true

    echo "Permissions et attributs définis dans l'environnement sécurisé"
}