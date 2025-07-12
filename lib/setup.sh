#!/bin/bash

: "${PATH_SEC:=/secure_env_data/secure_container.img}"
: "${NAME:=secure_env}"
: "${MOUNT:=/mnt/$NAME}"
: "${SIZE:=5G}"

create_conteneur_file() {
    mkdir -p "$(dirname "$PATH_SEC")" || {
        echo -e "$ERREUR Impossible de créer le répertoire $(dirname "$PATH_SEC")."
        exit 1
    }
    if [ -f "$PATH_SEC" ]; then
        echo "Fichier $PATH_SEC existe déjà, suppression..."
        rm -f "$PATH_SEC" || {
        echo -e "$ERREUR Impossible de supprimer $PATH_SEC."
        exit 1
        }
    fi
    echo "Création du fichier conteneur de taille $SIZE..."
    fallocate -l "$SIZE" "$PATH_SEC" || {
        echo -e "$ERREUR Échec de l'allocation du fichier conteneur."
        exit 1
    }
}

open_conteneur() {
    local password="$1"
    echo -n "$password" | cryptsetup open --key-file=- "$PATH_SEC" "$NAME" || {
        echo -e "$ERREUR Échec de l'ouverture du conteneur chiffré. Vérifiez le mot de passe."
        exit 1
    }
}

format_ext4() {
    echo "Formatage du conteneur en ext4..."
    mkfs.ext4 -F "/dev/mapper/$NAME" || {
        echo -e "$ERREUR Échec du formatage en ext4."
        exit 1
    }
}

close_conteneur() {
    echo "Tentative de fermeture du conteneur..."
    if mountpoint -q "$MOUNT"; then
        echo "Démontage de $MOUNT..."
        umount "$MOUNT" || {
            echo -e "$ERREUR Impossible de démonter $MOUNT."
            exit 1
        }
    fi
    cryptsetup close "$NAME" || {
        echo -e "$ERREUR Échec de la fermeture du conteneur '$NAME'."
        exit 1
    }
    echo "Conteneur fermé."
}

setup_env() {
    install_cryptsetup

    echo "--- Initialisation de l'environnement sécurisé ---"
    read -p "Taille de l'environnement (exemple: 5G, 10G) : " new_size

    if [[ ! "$new_size" =~ ^[0-9]+[GM]$ ]]; then
        echo -e "$ERREUR Taille invalide. Veuillez utiliser un format comme 5G ou 10G."
        exit 1
    fi
    SIZE="$new_size"

    read -s -p "Mot de passe pour le chiffrement : " password
    echo
    read -s -p "Veuillez confirmer le mot de passe : " password_confirm
    echo

    if [ "$password" != "$password_confirm" ]; then
        echo -e "$ERREUR Les mots de passe ne correspondent pas."
        exit 1
    fi

    create_conteneur_file

    echo "Attention ! Cette action écrasera définitivement les données sur $PATH_SEC."
    read -p "Tapez YES en majuscules pour continuer : " CONFIRM
    if [ "$CONFIRM" != "YES" ]; then
        cowsay "Abandon de l'installation."
        exit 0
    fi

    echo -n "$password" | cryptsetup luksFormat --batch-mode --key-file=- "$PATH_SEC" || {
        echo -e "$ERREUR Échec de la création du conteneur chiffré (luksFormat)."
        exit 1
    }

    open_conteneur "$password"
    format_ext4 

    mkdir -p "$MOUNT" || {
        echo -e "$ERREUR Impossible de créer le point de montage $MOUNT."
        cryptsetup close "$NAME"
        exit 1
    }
    mount "/dev/mapper/$NAME" "$MOUNT" || {
        echo -e "$ERREUR Échec du montage de /dev/mapper/$NAME sur $MOUNT pour les permissions."
        cryptsetup close "$NAME"
        exit 1
    }

    set_secure_permissions

    close_conteneur

    cowsay "Environnement sécurisé créé et fermé."
}

open_env() {
    install_figlet
    install_cowsay
    install_cryptsetup

    figlet "Secure env"
    cowsay "Ouverture de l'environnement..."

    if [ ! -f "$PATH_SEC" ]; then
        cowsay "Erreur: Fichier conteneur '$PATH_SEC' introuvable." >&2
        exit 1
    fi

    read -s -p "Mot de passe pour déverrouiller le conteneur : " password_open
    echo

    echo -n "$password_open" | cryptsetup open --key-file=- "$PATH_SEC" "$NAME" || {
        echo -e "$ERREUR Échec de l'ouverture du conteneur chiffré. Vérifiez le mot de passe."
        exit 1
    }

    mkdir -p "$MOUNT" || {
        echo -e "$ERREUR Impossible de créer le point de montage $MOUNT."
        cryptsetup close "$NAME"
        exit 1
    }

    mount "/dev/mapper/$NAME" "$MOUNT" || {
        echo -e "$ERREUR Échec du montage de /dev/mapper/$NAME sur $MOUNT."
        cryptsetup close "$NAME"
        exit 1
    }
    echo "Environnement ouvert et monté sur $MOUNT."

    echo
    echo "--- Informations sur le conteneur ---"
    lsblk "/dev/mapper/$NAME" || true
    echo
    sudo blkid "/dev/mapper/$NAME" || true
    echo
    df -h | grep "$MOUNT" || true
    echo "C'est bon !"
}

close_env() {
    install_figlet
    install_cowsay
    install_cryptsetup

    figlet "Secure env"
    cowsay "Fermeture de l'environnement..."

    if ! mountpoint -q "$MOUNT"; then
        echo "L'environnement n'est pas monté sur $MOUNT. Tentative de fermeture de LUKS."
    fi

    if pgrep -f "gpg-agent --homedir $cle_gpg_dir" &>/dev/null; then
        echo "Déconnexion du gpg-agent du trousseau du coffre..."
        pkill -f "gpg-agent --homedir $cle_gpg_dir"
        sleep 1
    fi

    close_conteneur
    cowsay "Environnement fermé."
}